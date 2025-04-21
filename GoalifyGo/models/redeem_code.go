package models

import (
	"time"
	"math/rand"
)

type RedeemCode struct {
	ID        string     `gorm:"primaryKey" json:"id"`
	Code      string     `gorm:"type:varchar(4);uniqueIndex" json:"code"`
	Energy    int        `gorm:"default:20" json:"energy"`
	CreatedAt time.Time  `json:"created_at"`
	UsedAt    *time.Time `json:"used_at"`
	UserID    *string    `gorm:"index" json:"user_id"`
}

// GenerateRedeemCode 生成4位随机兑换码
func GenerateRedeemCode() string {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // 去掉容易混淆的字符
	const codeLength = 4
	rand.Seed(time.Now().UnixNano())
	code := make([]byte, codeLength)
	for i := range code {
		code[i] = charset[rand.Intn(len(charset))]
	}
	return string(code)
}
