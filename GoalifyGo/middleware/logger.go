// 新增日志中间件
package middleware

import (
    "GoalifyGo/config"
    "time"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
)

func RequestLogger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        requestID := uuid.New().String()
        c.Set("requestID", requestID)
        
        c.Next()
        
        latency := time.Since(start)
        config.Logger.Infow("request",
            "requestID", requestID,
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "clientIP", c.ClientIP(),
            "latency", latency.String(),
            "userAgent", c.Request.UserAgent(),
        )
    }
} 