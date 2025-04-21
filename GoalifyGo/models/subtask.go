package models

import "time"

// Subtask 子任务模型
type Subtask struct {
	ID           string    `gorm:"type:varchar(50);primaryKey" json:"id"`
	Title        string    `gorm:"type:varchar(100)" json:"title"`
	IsCompleted  bool      `gorm:"default:false" json:"isCompleted"`
	TaskID       string    `gorm:"type:varchar(50)" json:"task_id"`
	UserID       string    `gorm:"type:varchar(50)" json:"user_id"`
	LastModified time.Time `json:"lastModified"`
}
