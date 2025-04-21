package middleware

import (
	"GoalifyGo/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

// AuthMiddleware 认证中间件
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := c.GetHeader("Authorization")
		if tokenString == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未提供认证信息"})
			return
		}

		// 解析 JWT
		claims, err := utils.ParseToken(tokenString)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "无效的认证信息"})
			return
		}

		// 将 uid 存储在 gin.Context 中
		c.Set("uid", claims.UserID)
		c.Next()
	}
}
