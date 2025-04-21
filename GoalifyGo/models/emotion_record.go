package models

import "time"

// EmotionRecord 情绪记录模型
type EmotionRecord struct {
	ID               string    `gorm:"type:varchar(50);primaryKey" json:"id"`
	EmotionType      string    `gorm:"type:varchar(50)" json:"emotionType"`
	Intensity        int       `json:"intensity"`
	Trigger          string    `gorm:"type:text" json:"trigger"`
	UnhealthyBeliefs string    `gorm:"type:text" json:"unhealthyBeliefs"`
	HealthyEmotion   string    `gorm:"type:varchar(50)" json:"healthyEmotion"`
	CopingStrategies string    `gorm:"type:text" json:"copingStrategies"`
	Status           int       `gorm:"type:int" default:"0" json:"status"` // 0: 正常 1: 删除
	RecordDate       time.Time `json:"recordDate"`
	UserID           string    `gorm:"type:varchar(50)" json:"user_id"`
	LastModified     time.Time `json:"lastModified"`
}
