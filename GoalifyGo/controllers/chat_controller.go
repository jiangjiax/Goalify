package controllers

import (
	"GoalifyGo/config"
	"GoalifyGo/models"
	"GoalifyGo/services"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ChatController struct {
	chatService *services.ChatService
	wg          sync.WaitGroup // 添加 WaitGroup
}

func NewChatController(chatService *services.ChatService) *ChatController {
	return &ChatController{
		chatService: chatService,
	}
}

// SendMessage handles chat requests from clients
func (c *ChatController) SendMessage(ctx *gin.Context) {
	// 获取用户信息
	uid, exists := ctx.Get("uid")
	if !exists {
		config.Logger.Errorw("未获取到用户ID")
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "未获取到用户ID"})
		return
	}

	// 检查用户能量值
	var user models.User
	if err := config.DB.Where("id = ?", uid).First(&user).Error; err != nil {
		config.Logger.Errorw("获取用户信息失败", "error", err, "uid", uid)
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	if user.Energy < 1 {
		ctx.JSON(http.StatusForbidden, gin.H{
			"error":           "能量值不足，请充值",
			"remainingEnergy": user.Energy,
		})
		return
	}

	// 扣除能量值
	if err := config.DB.Model(&user).Update("energy", user.Energy-1).Error; err != nil {
		config.Logger.Errorw("扣除能量值失败", "error", err, "uid", uid)
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "扣除能量值失败"})
		return
	}

	var chatRequest struct {
		Message   string `json:"message" binding:"required"`
		Scene     string `json:"scene"`      // goal, emotion, chat
		CoachType string `json:"coach_type"` // logic, orange
	}

	// 绑定 JSON 请求
	if err := ctx.ShouldBindJSON(&chatRequest); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request: " + err.Error(),
		})
		return
	}

	// 生成会话 ID
	sessionID := fmt.Sprintf("%s_%s", uid, chatRequest.Scene)

	// 从 Redis 中获取对话历史总结
	historySummary, err := config.RedisClient.Get(ctx, sessionID).Result()
	if err != nil {
		config.Logger.Errorw("获取对话历史总结失败",
			"error", err,
			"sessionID", sessionID,
			"uid", uid,
		)
	}

	// 设置流式响应头
	ctx.Header("Content-Type", "text/event-stream")
	ctx.Header("Cache-Control", "no-cache")
	ctx.Header("Connection", "keep-alive")
	ctx.Header("Access-Control-Allow-Origin", "*")
	ctx.Header("X-Accel-Buffering", "no") // 禁用 Nginx 缓冲

	var aiScene services.AIScene
	var aiCoach services.AICoach

	switch chatRequest.Scene {
	case "goal":
		aiScene = services.GoalScene
		aiCoach = services.LogicCoach
	case "emotion":
		aiScene = services.EmotionScene
		aiCoach = services.OrangeCoach
	default:
		aiScene = services.ChatScene
		aiCoach = services.OrangeCoach
	}

	// 处理聊天请求
	stream, err := c.chatService.GenerateCoachResponse(
		ctx,
		aiCoach,
		aiScene,
		chatRequest.Message,
		historySummary,
		uid.(string), // 传入 uid
	)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to process chat: " + err.Error(),
		})
		return
	}

	// 发送流式响应
	var fullResponse strings.Builder
	for chunk := range stream {
		_, err := ctx.Writer.Write([]byte(chunk))
		if err != nil {
			log.Printf("Write error: %v", err)
			return
		}
		ctx.Writer.Flush() // 确保每个块都被立即发送
		fullResponse.WriteString(chunk)
	}
}

// AnalyzeReview 处理复盘分析请求
func (c *ChatController) AnalyzeReview(ctx *gin.Context) {
	// 获取用户信息
	uid, exists := ctx.Get("uid")
	if !exists {
		config.Logger.Errorw("未获取到用户ID")
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "未获取到用户ID"})
		return
	}

	// 检查用户能量值
	var user models.User
	if err := config.DB.Where("id = ?", uid).First(&user).Error; err != nil {
		config.Logger.Errorw("获取用户信息失败", "error", err, "uid", uid)
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	// 解析请求参数
	var request models.ReviewAnalysisRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request: " + err.Error(),
		})
		return
	}

	// 验证并转换时区
	if err := request.Validate(); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request: " + err.Error(),
		})
		return
	}

	// 根据复盘周期计算需要扣除的能量值
	var energyCost int
	switch request.Period {
	case "day":
		energyCost = 1
	case "week":
		energyCost = 1
	case "month":
		energyCost = 3
	default:
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid period"})
		return
	}

	// 检查用户能量值是否足够
	if user.Energy < energyCost {
		ctx.JSON(http.StatusForbidden, gin.H{
			"error":           fmt.Sprintf("能量值不足，需要%d点，当前剩余%d点", energyCost, user.Energy),
			"remainingEnergy": user.Energy,
		})
		return
	}

	// 查询情绪记录
	var emotions []models.EmotionRecord
	if err := config.DB.Where("user_id = ? AND record_date BETWEEN ? AND ?",
		uid, request.StartDate, request.EndDate).Find(&emotions).Error; err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "获取情绪记录失败"})
		return
	}
	config.Logger.Debugw("查询到的情绪记录", "count", len(emotions))

	// 扣除能量值
	if err := config.DB.Model(&user).Update("energy", user.Energy-energyCost).Error; err != nil {
		config.Logger.Errorw("扣除能量值失败", "error", err, "uid", uid)
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "扣除能量值失败"})
		return
	}

	// 查询上一次同周期的复盘总结
	var previousAnalysis models.ReviewAnalysis
	err := config.DB.Where("user_id = ? AND period = ? AND start_date < ?",
		uid.(string), request.Period, request.StartDate).
		Order("start_date desc").
		First(&previousAnalysis).Error

	var previousSummary string
	if err == nil {
		previousSummary = previousAnalysis.Summary
	}

	// 设置流式响应头
	ctx.Header("Content-Type", "text/event-stream")
	ctx.Header("Cache-Control", "no-cache")
	ctx.Header("Connection", "keep-alive")
	ctx.Header("Access-Control-Allow-Origin", "*")
	ctx.Header("X-Accel-Buffering", "no")

	// 处理复盘分析请求
	stream, err := c.chatService.GenerateReviewAnalysis(ctx, request.Period, request.TimeRecord, emotions, previousSummary)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to process review analysis: " + err.Error(),
		})
		return
	}

	// 发送流式响应
	var fullResponse strings.Builder
	for chunk := range stream {
		_, err := ctx.Writer.Write([]byte(chunk))
		if err != nil {
			log.Printf("Write error: %v", err)
			return
		}
		ctx.Writer.Flush()
		fullResponse.WriteString(chunk)
	}

	// 在协程中存储分析结果
	c.wg.Add(1) // 增加 WaitGroup 计数
	go func() {
		defer c.wg.Done() // 完成后减少计数

		// 检查是否已存在相同记录
		var existingAnalysis models.ReviewAnalysis
		err := config.DB.Where("user_id = ? AND period = ? AND start_date = ? AND end_date = ?",
			uid.(string), request.Period, request.StartDate, request.EndDate).First(&existingAnalysis).Error

		if err == nil {
			// 如果记录已存在，更新 Summary
			if err := config.DB.Model(&existingAnalysis).Update("summary", fullResponse.String()).Error; err != nil {
				config.Logger.Errorw("更新复盘分析结果失败",
					"error", err,
					"uid", uid,
					"period", request.Period,
				)
			}
		} else if err == gorm.ErrRecordNotFound {
			// 如果记录不存在，创建新记录
			analysis := models.ReviewAnalysis{
				ID:        uuid.New().String(),
				UserID:    uid.(string),
				Period:    request.Period,
				StartDate: request.StartDate,
				EndDate:   request.EndDate,
				Summary:   fullResponse.String(),
				CreatedAt: time.Now(),
			}

			if err := config.DB.Create(&analysis).Error; err != nil {
				config.Logger.Errorw("存储复盘分析结果失败",
					"error", err,
					"uid", uid,
					"period", request.Period,
				)
			}
		} else {
			// 其他错误
			config.Logger.Errorw("查询复盘分析记录失败",
				"error", err,
				"uid", uid,
				"period", request.Period,
			)
		}
	}()
}

// GetReviewAnalyses 获取用户的复盘分析记录
func (c *ChatController) GetReviewAnalyses(ctx *gin.Context) {
	// 获取用户信息
	uid, exists := ctx.Get("uid")
	if !exists {
		config.Logger.Errorw("未获取到用户ID")
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "未获取到用户ID"})
		return
	}

	// 查询参数
	period := ctx.Query("period")
	startDate := ctx.Query("startDate")
	endDate := ctx.Query("endDate")

	// 验证参数
	if period == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "缺少复盘周期参数"})
		return
	}
	if startDate == "" || endDate == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "缺少时间范围参数"})
		return
	}

	// 定义 ISO 8601 时间格式
	layout := "2006-01-02T15:04:05Z07:00"

	// 解析时间字符串为 time.Time
	startTimeParsed, err := time.Parse(layout, startDate)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "无效的开始时间格式"})
		return
	}
	endTimeParsed, err := time.Parse(layout, endDate)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "无效的结束时间格式"})
		return
	}

	// 打印查询参数
	fmt.Printf("查询参数 - userID: %s, period: %s, startDate: %s, endDate: %s\n", uid, period, startTimeParsed, endTimeParsed)

	// 构建查询
	query := config.DB.Where("user_id = ? AND period = ?", uid, period)
	query = query.Where("start_date = ? AND end_date = ?",
		startTimeParsed,
		endTimeParsed)

	// 查询结果
	var analysis models.ReviewAnalysis
	if err := query.First(&analysis).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			fmt.Println("未找到对应的复盘记录")
			ctx.JSON(http.StatusNotFound, gin.H{"error": "未找到对应的复盘记录"})
		} else {
			fmt.Printf("获取复盘分析记录失败: %v\n", err)
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": "获取复盘分析记录失败"})
		}
		return
	}

	fmt.Println("成功获取复盘分析记录")
	ctx.JSON(http.StatusOK, gin.H{
		"data": analysis,
	})
}

// 添加 Wait 方法用于优雅关闭
func (c *ChatController) Wait() {
	c.wg.Wait()
}
