package models

import (
	"time"
)

// Task 任务模型
type Task struct {
	ID           string     `gorm:"type:varchar(50);primary_key" json:"id"`
	Title        string     `gorm:"type:varchar(100)" json:"title"`
	IsCompleted  bool       `json:"isCompleted"`
	Notes        string     `gorm:"type:text" json:"notes"`
	Deadline     *time.Time `json:"deadline"`
	PlannedDate  *time.Time `json:"plannedDate,omitempty"`
	Difficulty   int        `gorm:"default:1" json:"difficulty"`      // 难度
	Quadrant     string     `gorm:"type:varchar(30)" json:"quadrant"` // 四象限
	UserID       string     `gorm:"type:varchar(50)" json:"user_id"`
	FocusTime    int        `gorm:"default:0" json:"focusTime"` // 专注时间
	LastModified time.Time  `json:"lastModified"`
	RepeatType   string     `gorm:"type:varchar(30)" json:"repeatType"` // 重复类型
}
