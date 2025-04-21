package models

import (
	"time"
)

// User 用户模型
type User struct {
	ID                string     `gorm:"type:varchar(50);primaryKey" json:"id"`
	Username          string     `gorm:"type:varchar(100)" json:"username"`
	Email             string     `gorm:"type:varchar(100)" json:"email"`
	CreatedAt         time.Time  `json:"createdAt"`
	Avatar            string     `gorm:"type:varchar(255)" json:"avatar"`
	LastLogin         *time.Time `json:"last_login,omitempty"`
	Provider          string     `gorm:"type:varchar(50)" json:"provider"`
	ProviderID        string     `gorm:"type:varchar(50)" json:"providerId"`
	AppleRefreshToken string     `gorm:"type:varchar(255)" json:"-"`
	IsTestUser        bool       `gorm:"default:false" json:"isTestUser"`
	Energy            int        `gorm:"default:20" json:"energy"` // 用户能量值，默认20
}

func (u *User) GetDisplayName() string {
	if u.Username != "" {
		return u.Username
	}
	return u.Email
}
