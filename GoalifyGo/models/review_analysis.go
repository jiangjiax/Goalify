package models

import (
	"time"
)

type ReviewAnalysis struct {
	ID         string    `gorm:"primaryKey"`
	UserID     string    `gorm:"index:idx_user_period_date,unique"`
	Period     string    `gorm:"type:varchar(20);index:idx_user_period_date,unique"`
	StartDate  time.Time `gorm:"index:idx_user_period_date,unique"`
	EndDate    time.Time `gorm:"index:idx_user_period_date,unique"`
	Summary    string    `gorm:"type:text"`
	CreatedAt  time.Time
}

func (ReviewAnalysis) TableName() string {
	return "review_analyses"
} 