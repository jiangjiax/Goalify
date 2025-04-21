package config

import (
	"fmt"
	"github.com/spf13/viper"
)

// Config 存储所有配置信息
type Config struct {
	Environment string `mapstructure:"ENVIRONMENT"`
	ServerPort  string `mapstructure:"SERVER_PORT"`

	// 数据库配置
	DBHost     string `mapstructure:"DB_HOST"`
	DBPort     string `mapstructure:"DB_PORT"`
	DBUser     string `mapstructure:"DB_USER"`
	DBPassword string `mapstructure:"DB_PASSWORD"`
	DBName     string `mapstructure:"DB_NAME"`

	// Redis配置
	RedisHost     string `mapstructure:"REDIS_HOST"`
	RedisPort     string `mapstructure:"REDIS_PORT"`
	RedisPassword string `mapstructure:"REDIS_PASSWORD"`
	RedisDB       int    `mapstructure:"REDIS_DB"`

	// Deepseek API配置
	DeepseekAPIKey      string `mapstructure:"DEEPSEEK_API_KEY"`
	DeepseekAPIEndpoint string `mapstructure:"DEEPSEEK_API_ENDPOINT"`

	// 微信登录配置
	WechatAppID     string `mapstructure:"WECHAT_APP_ID"`
	WechatAppSecret string `mapstructure:"WECHAT_APP_SECRET"`

	// 苹果登录配置
	AppleTeamID     string `mapstructure:"APPLE_TEAM_ID"`
	AppleClientID   string `mapstructure:"APPLE_CLIENT_ID"`
	AppleKeyID      string `mapstructure:"APPLE_KEY_ID"`
	ApplePrivateKey string `mapstructure:"APPLE_PRIVATE_KEY"`

	// JWT配置
	JWTSecret string `mapstructure:"JWT_SECRET"`
}

// LoadConfig 从环境变量或配置文件加载配置
func LoadConfig(path string) (config Config, err error) {
	viper.AddConfigPath(path)
	viper.SetConfigName(".env")
	viper.SetConfigType("env")

	viper.AutomaticEnv()

	err = viper.ReadInConfig()
	if err != nil {
		// 允许配置文件不存在，此时会从环境变量中读取
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return
		}
	}

	err = viper.Unmarshal(&config)
	return
}

// GetDBConnString 返回数据库连接字符串
func (c *Config) GetDBConnString() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName)
}

// GetRedisConnString 返回Redis连接字符串
func (c *Config) GetRedisConnString() string {
	return fmt.Sprintf("%s:%s", c.RedisHost, c.RedisPort)
}
