package middleware

import (
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

// InternalAuthMiddleware 内部接口认证中间件
func InternalAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取请求头中的认证信息
		authToken := c.GetHeader("X-Internal-Auth")
		
		// 验证认证信息
		if authToken != os.Getenv("INTERNAL_AUTH_TOKEN") {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": "Forbidden",
			})
			return
		}
		
		c.Next()
	}
} 