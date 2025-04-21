package utils

import (
	"fmt"
	"log"
	"time"

	"GoalifyGo/config"
	"github.com/golang-jwt/jwt/v4"
)

var jwtKey []byte

// Claims 自定义JWT声明
type Claims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken 生成JWT令牌
func GenerateToken(userID string) (string, error) {
	log.Printf("Generating token for user ID: %s", userID)
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour * 30)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtKey)
}

// ParseToken 解析JWT令牌
func ParseToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtKey, nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("无效的令牌")
}

// 在init函数中初始化
func init() {
	config, err := config.LoadConfig(".")
	if err != nil {
		panic("Failed to load config: " + err.Error())
	}
	jwtKey = []byte(config.JWTSecret)
}
