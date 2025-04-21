package models

import (
	"time"
)

type TimeRecord struct {
	ID           string `gorm:"type:varchar(50);primary_key"`
	UserID       string `gorm:"index:idx_time_records_user_start"`
	TaskID       string `gorm:"type:varchar(50);index:idx_time_records_task"`
	StartTime    time.Time `gorm:"index:idx_time_records_user_start"`
	EndTime      time.Time
	LastModified time.Time
}

// 表名
func (TimeRecord) TableName() string {
	return "time_records"
}
