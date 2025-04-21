package controllers

import (
	"GoalifyGo/config"
	"GoalifyGo/models"
	"github.com/gin-gonic/gin"
	"net/http"
	"time"
)

type SyncController struct{}

// GetUpdates 获取自上次同步以来的更新
func (sc *SyncController) GetUpdates(c *gin.Context) {
	// 获取用户ID
	uid, exists := c.Get("uid")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未获取到用户ID"})
		return
	}

	// 获取上次同步时间
	lastSyncDateStr := c.Query("lastSyncDate")
	var lastSyncDate time.Time
	var err error

	if lastSyncDateStr != "" {
		lastSyncDate, err = time.Parse(time.RFC3339, lastSyncDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的时间格式"})
			return
		}
	} else {
		// 如果没有提供上次同步时间，则使用很久以前的时间
		lastSyncDate = time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	// 计算一个月前的时间
	oneMonthAgo := time.Now().AddDate(0, -1, 0)

	// 查询情绪记录更新
	var emotions []models.EmotionRecord
	if err := config.DB.Where("user_id = ? AND last_modified > ? AND last_modified > ? AND status = 0",
		uid, lastSyncDate, oneMonthAgo).Find(&emotions).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取情绪记录更新失败"})
		return
	}

	emotionResponses := make([]models.EmotionResponse, len(emotions))
	for i, emotion := range emotions {
		emotionResponses[i] = models.EmotionResponse{
			ID:               emotion.ID,
			EmotionType:      emotion.EmotionType,
			Intensity:        emotion.Intensity,
			Trigger:          emotion.Trigger,
			UnhealthyBeliefs: emotion.UnhealthyBeliefs,
			HealthyEmotion:   emotion.HealthyEmotion,
			CopingStrategies: emotion.CopingStrategies,
			RecordDate:       emotion.RecordDate,
			LastModified:     emotion.LastModified,
		}
	}

	// 返回响应
	c.JSON(http.StatusOK, models.SyncUpdatesResponse{
		Emotions: emotionResponses,
	})
}
