package controllers

import (
	"GoalifyGo/config"
	"GoalifyGo/models"
	"GoalifyGo/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type RedeemController struct{}

// CreateRedeemCode 创建兑换码
func (rc *RedeemController) CreateRedeemCode(c *gin.Context) {
	energy := c.Query("energy")
	energyInt := 20
	if energy != "" {
		var err error
		energyInt, err = strconv.Atoi(energy)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的能量值"})
			return
		}
	}

	password := c.Query("password")
	if password != "832251086jjxG@" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "fuck you"})
		return
	}

	// 生成4位兑换码
	code := models.GenerateRedeemCode()

	// 创建兑换码记录
	redeemCode := models.RedeemCode{
		ID:        utils.GenerateID(),
		Code:      code,
		Energy:    energyInt, // 默认20点能量
		CreatedAt: time.Now(),
	}

	// 保存到数据库
	if err := config.DB.Create(&redeemCode).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建兑换码失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":      redeemCode.Code,
		"energy":    redeemCode.Energy,
		"createdAt": redeemCode.CreatedAt,
	})
}

// RedeemCode 兑换能量码
func (rc *RedeemController) RedeemCode(c *gin.Context) {
	var req struct {
		Code string `json:"code" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的请求"})
		return
	}

	// 获取用户ID
	uid, exists := c.Get("uid")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未认证用户"})
		return
	}

	// 查找兑换码
	var redeemCode models.RedeemCode
	if err := config.DB.Where("code = ?", req.Code).First(&redeemCode).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "兑换码不存在"})
		return
	}

	// 检查是否已使用
	if redeemCode.UsedAt != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "兑换码已使用"})
		return
	}

	// 更新用户能量
	var user models.User
	if err := config.DB.Where("id = ?", uid).First(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "用户不存在"})
		return
	}

	// 更新兑换码状态
	now := time.Now()
	redeemCode.UsedAt = &now
	redeemCode.UserID = &user.ID

	// 开启事务
	tx := config.DB.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 更新用户能量
	if err := tx.Model(&user).Update("energy", user.Energy+redeemCode.Energy).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新用户能量失败"})
		return
	}

	// 更新兑换码状态
	if err := tx.Save(&redeemCode).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新兑换码状态失败"})
		return
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "兑换失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "兑换成功",
		"newEnergy": user.Energy + redeemCode.Energy,
	})
}
