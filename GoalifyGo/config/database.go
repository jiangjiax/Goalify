package config

import (
	"GoalifyGo/models"
	"fmt"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// InitDB 初始化数据库连接
func InitDB(config Config) error {
	dsn := config.GetDBConnString()

	var err error
	DB, err = gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return err
	}

	// 设置连接池
	sqlDB, err := DB.DB()
	if err != nil {
		return err
	}

	// 设置连接池参数
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)

	// 自动迁移表结构
	//err = migrateDB()
	//if err != nil {
	//	return fmt.Errorf("数据库迁移失败: %v", err)
	//}

	return nil
}

// migrateDB 进行数据库表结构迁移
func migrateDB() error {
	// 自动迁移所有表
	err := DB.AutoMigrate(
		&models.User{},
		&models.Task{},
		&models.Subtask{},
		&models.EmotionRecord{},
		&models.RedeemCode{},
		&models.TimeRecord{},
		&models.ReviewAnalysis{},
	)
	if err != nil {
		return fmt.Errorf("数据库迁移失败: %v", err)
	}

	// 手动创建索引
	// if err := DB.Exec(`
	// 	CREATE INDEX IF NOT EXISTS idx_time_records_user_start ON time_records(user_id, start_time);
	// 	CREATE INDEX IF NOT EXISTS idx_time_records_task ON time_records(task_id);
	// 	CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(user_id);
	// 	CREATE INDEX IF NOT EXISTS idx_review_analyses_user ON review_analyses(user_id);
	// `).Error; err != nil {
	// 	return fmt.Errorf("创建索引失败: %v", err)
	// }

	return nil
}
