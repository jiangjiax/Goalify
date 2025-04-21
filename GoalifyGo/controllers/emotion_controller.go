package controllers

import (
	"GoalifyGo/config"
	"GoalifyGo/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type EmotionController struct{}

// SyncEmotions 处理情绪记录同步
func (ec *EmotionController) SyncEmotions(c *gin.Context) {
	var emotions []models.SyncEmotionsRequest
	if err := c.ShouldBindJSON(&emotions); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   err.Error(),
		})
		return
	}

	// 获取用户ID
	uid, exists := c.Get("uid")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未获取到用户ID"})
		return
	}

	// 开启事务
	tx := config.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 更新或创建情绪记录
	for _, emotionReq := range emotions {
		emotion := models.EmotionRecord{
			ID:              emotionReq.ID,
			EmotionType:     emotionReq.EmotionType,
			Intensity:       emotionReq.Intensity,
			Trigger:         emotionReq.Trigger,
			UnhealthyBeliefs: emotionReq.UnhealthyBeliefs,
			HealthyEmotion:  emotionReq.HealthyEmotion,
			CopingStrategies: emotionReq.CopingStrategies,
			RecordDate:      emotionReq.RecordDate,
			LastModified:    emotionReq.LastModified,
			UserID:          uid.(string),
		}

		// 检查是否存在同名情绪记录
		var existingEmotion models.EmotionRecord
		if err := tx.Where("id = ?", emotion.ID).First(&existingEmotion).Error; err == nil {
			// 如果存在，比较 lastModified 时间戳
			if emotion.LastModified.After(existingEmotion.LastModified) {
				// 如果新数据更晚，更新情绪记录
				emotion.LastModified = time.Now()
				if err := tx.Save(&emotion).Error; err != nil {
					tx.Rollback()
					c.JSON(http.StatusInternalServerError, gin.H{"error": "情绪记录同步失败"})
					return
				}
			} else {
				// 如果旧数据更晚，忽略新数据
				continue
			}
		} else {
			// 如果不存在，创建新情绪记录
			emotion.LastModified = time.Now()
			if err := tx.Create(&emotion).Error; err != nil {
				tx.Rollback()
				c.JSON(http.StatusInternalServerError, gin.H{"error": "情绪记录同步失败"})
				return
			}
		}
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "情绪记录同步失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "情绪记录同步成功"})
} 