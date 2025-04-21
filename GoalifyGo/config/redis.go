package config

import (
	"fmt"
	
	"github.com/go-redis/redis/v8"
	"golang.org/x/net/context"
)

var RedisClient *redis.Client
var ctx = context.Background()

// InitRedis 初始化Redis客户端
func InitRedis(config Config) error {
	RedisClient = redis.NewClient(&redis.Options{
		Addr:     config.GetRedisConnString(),
		Password: config.RedisPassword,
		DB:       config.RedisDB,
	})
	
	// 测试连接
	_, err := RedisClient.Ping(ctx).Result()
	if err != nil {
		return fmt.Errorf("Redis连接测试失败: %v", err)
	}
	
	return nil
} 