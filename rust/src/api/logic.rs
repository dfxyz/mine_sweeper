use std::collections::HashSet;

use flutter_rust_bridge::frb;
use rand::Rng;
use crate::constants;

pub struct GameState {
    pub setting: GameSetting,
    pub mine_field_cells: Vec<MineFieldCell>,
    pub game_result: GameResult,
}

#[derive(Copy, Clone)]
pub enum GameSetting {
    Easy,
    Medium,
    Hard,
    Custom {
        mine_field_width: u32,
        mine_field_height: u32,
        mine_num: u32,
    },
}
impl GameSetting {
    #[frb(sync, getter)]
    pub fn mine_field_width(&self) -> u32 {
        match self {
            GameSetting::Easy => constants::EASY_MINE_FIELD_WIDTH,
            GameSetting::Medium => constants::MEDIUM_MINE_FIELD_WIDTH,
            GameSetting::Hard => constants::HARD_MINE_FIELD_WIDTH,
            GameSetting::Custom {
                mine_field_width, ..
            } => *mine_field_width,
        }
    }

    #[frb(sync, getter)]
    pub fn mine_field_height(&self) -> u32 {
        match self {
            GameSetting::Easy => constants::EASY_MINE_FIELD_HEIGHT,
            GameSetting::Medium => constants::MEDIUM_MINE_FIELD_HEIGHT,
            GameSetting::Hard => constants::HARD_MINE_FIELD_HEIGHT,
            GameSetting::Custom {
                mine_field_height, ..
            } => *mine_field_height,
        }
    }

    #[frb(sync, getter)]
    pub fn mine_num(&self) -> u32 {
        match self {
            GameSetting::Easy => constants::EASY_MINE_NUM,
            GameSetting::Medium => constants::MEDIUM_MINE_NUM,
            GameSetting::Hard => constants::HARD_MINE_NUM,
            GameSetting::Custom { mine_num, .. } => *mine_num,
        }
    }

    fn verify(&self) -> bool {
        match self {
            GameSetting::Easy | GameSetting::Medium | GameSetting::Hard => true,
            GameSetting::Custom {
                mine_field_width,
                mine_field_height,
                mine_num,
            } => {
                if *mine_field_width <= 1 {
                    return false;
                }
                if *mine_field_height <= 1 {
                    return false;
                }
                if *mine_num < 1 || *mine_num >= *mine_field_width * *mine_field_height {
                    return false;
                }
                true
            }
        }
    }
}

#[derive(Copy, Clone)]
pub enum MineFieldCell {
    Unrevealed,
    Revealed(u32),
    Flagged,
    Mine,
    ExplodedMine,
    CorrectlyFlagged,
    IncorrectlyFlagged,
}

#[derive(Copy, Clone, Eq, PartialEq)]
pub enum GameResult {
    Playing,
    Win,
    Lose,
}

impl GameState {
    #[frb(sync)]
    pub fn new() -> Self {
        let setting = GameSetting::Easy;
        let num_cells = setting.mine_field_width() * setting.mine_field_height();
        let mine_field_cells = vec![MineFieldCell::Unrevealed; num_cells as usize];
        let game_result = GameResult::Playing;
        Self {
            setting,
            mine_field_cells,
            game_result,
        }
    }
}

#[frb(opaque)]
pub struct GameLogicInner {
    setting: GameSetting,
    mine_field_cells: Vec<MineFieldCell>,
    mine_cell_indexes: Option<HashSet<usize>>,
    to_reveal_cell_num: usize,
    game_result: GameResult,
}

impl GameLogicInner {
    #[frb(sync)]
    pub fn new() -> Self {
        let setting = GameSetting::Easy;
        let num_cells = setting.mine_field_width() * setting.mine_field_height();
        let mine_field_cells = vec![MineFieldCell::Unrevealed; num_cells as usize];
        let mine_cell_indexes = None;
        let to_reveal_cell_num = (num_cells - setting.mine_num()) as usize;
        let game_result = GameResult::Playing;
        Self {
            setting,
            mine_field_cells,
            mine_cell_indexes,
            to_reveal_cell_num,
            game_result,
        }
    }

    #[frb(sync)]
    pub fn get_state(&self) -> GameState {
        GameState {
            setting: self.setting,
            mine_field_cells: self.mine_field_cells.clone(),
            game_result: self.game_result,
        }
    }

    #[frb(sync)]
    pub fn restart_game(&mut self, setting: Option<GameSetting>) -> bool {
        let setting = setting.unwrap_or(self.setting);
        if !setting.verify() {
            return false;
        }
        self.setting = setting;
        let num_cells = setting.mine_field_width() * setting.mine_field_height();
        self.mine_field_cells = vec![MineFieldCell::Unrevealed; num_cells as usize];
        self.mine_cell_indexes = None;
        self.to_reveal_cell_num = (num_cells - setting.mine_num()) as usize;
        self.game_result = GameResult::Playing;
        true
    }

    #[inline]
    fn grid2index(&self, x: u32, y: u32) -> usize {
        (y * self.setting.mine_field_width() + x) as usize
    }

    fn surrounding_grids(&self, x: u32, y: u32) -> Vec<(u32, u32)> {
        let mut grids = Vec::with_capacity(8);
        let width = self.setting.mine_field_width();
        let height = self.setting.mine_field_height();
        for i in -1..=1 {
            for j in -1..=1 {
                if i == 0 && j == 0 {
                    continue;
                }
                let new_x = x as i32 + i;
                let new_y = y as i32 + j;
                if new_x < 0 || new_x >= width as i32 || new_y < 0 || new_y >= height as i32 {
                    continue;
                }
                grids.push((new_x as u32, new_y as u32));
            }
        }
        grids
    }

    #[frb(sync)]
    pub fn reveal_mine_field_cell(&mut self, x: u32, y: u32) -> bool {
        if self.game_result != GameResult::Playing {
            return false;
        }
        let index = self.grid2index(x, y);
        if index > self.mine_field_cells.len() {
            return false;
        }
        match self.mine_field_cells[index] {
            MineFieldCell::Unrevealed => {}
            _ => return false,
        }

        if let None = &self.mine_cell_indexes {
            self.init_mine_cell_indexes(index);
        }
        let mine_indexes = self.mine_cell_indexes.as_ref().unwrap();

        if mine_indexes.contains(&index) {
            self.on_mine_revealed(index);
            return true;
        }

        let surrounding_grids = self.surrounding_grids(x, y);
        let mut surrounding_mine_num = 0;
        for (x, y) in &surrounding_grids {
            let i = self.grid2index(*x, *y);
            if mine_indexes.contains(&i) {
                surrounding_mine_num += 1;
                continue;
            }
        }
        self.mine_field_cells[index] = MineFieldCell::Revealed(surrounding_mine_num);
        self.to_reveal_cell_num -= 1;
        if self.to_reveal_cell_num == 0 {
            self.game_result = GameResult::Win;
            return true;
        }
        if surrounding_mine_num == 0 {
            for (x, y) in &surrounding_grids {
                self.reveal_mine_field_cell(*x, *y);
            }
        }
        true
    }

    fn init_mine_cell_indexes(&mut self, excluded_index: usize) {
        let len = (self.setting.mine_field_width() * self.setting.mine_field_height() - 1) as usize;
        let mine_num = self.setting.mine_num() as usize;
        let mut vec = (0..len).collect::<Vec<usize>>();
        let mut rng = rand::rng();
        for i in 0..mine_num {
            let index = rng.random_range(i..len);
            vec.swap(i, index);
        }
        let mut set = HashSet::with_capacity(mine_num);
        for i in 0..mine_num {
            if vec[i] >= excluded_index {
                set.insert(vec[i] + 1);
            } else {
                set.insert(vec[i]);
            }
        }
        self.mine_cell_indexes.replace(set);
    }

    fn on_mine_revealed(&mut self, index: usize) {
        self.game_result = GameResult::Lose;
        let mine_indexes = self.mine_cell_indexes.as_ref().unwrap();
        for (i, cell) in self.mine_field_cells.iter_mut().enumerate() {
            if i == index {
                *cell = MineFieldCell::ExplodedMine;
                continue;
            }
            match cell {
                MineFieldCell::Unrevealed => {
                    if mine_indexes.contains(&i) {
                        *cell = MineFieldCell::Mine;
                    }
                }
                MineFieldCell::Flagged => {
                    if mine_indexes.contains(&i) {
                        *cell = MineFieldCell::CorrectlyFlagged;
                    } else {
                        *cell = MineFieldCell::IncorrectlyFlagged;
                    }
                }
                _ => {}
            }
        }
    }

    #[frb(sync)]
    pub fn toggle_flag_on_mine_field_cell(&mut self, x: u32, y: u32) -> bool {
        if self.game_result != GameResult::Playing {
            return false;
        }
        let index = self.grid2index(x, y);
        if index > self.mine_field_cells.len() {
            return false;
        }
        match self.mine_field_cells[index] {
            MineFieldCell::Unrevealed => {
                self.mine_field_cells[index] = MineFieldCell::Flagged;
            }
            MineFieldCell::Flagged => {
                self.mine_field_cells[index] = MineFieldCell::Unrevealed;
            }
            _ => {}
        }
        true
    }
}
