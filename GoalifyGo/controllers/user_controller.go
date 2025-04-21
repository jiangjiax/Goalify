package controllers

import (
	"fmt"
	"net/http"
	"strconv"

	"GoalifyGo/config"
	"GoalifyGo/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type UserController struct{}

func (uc *UserController) AddEnergy(c *gin.Context) {
	// 记录内部接口调用
	config.Logger.Infow("内部接口调用：增加能量值",
		"sourceIP", c.ClientIP(),
		"userAgent", c.Request.UserAgent(),
	)

	uid := c.Query("uid")
	amountStr := c.Query("amount")

	// 转换amount为整数
	amount, err := strconv.Atoi(amountStr)
	if err != nil || amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的能量值"})
		return
	}

	var user models.User
	if err := config.DB.Where("id = ?", uid).First(&user).Error; err != nil {
		config.Logger.Errorw("获取用户信息失败", "error", err, "uid", uid)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	if err := config.DB.Model(&user).Update("energy", user.Energy+amount).Error; err != nil {
		config.Logger.Errorw("增加能量值失败", "error", err, "uid", uid)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "增加能量值失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "能量值增加成功",
		"newEnergy": user.Energy + amount,
	})
}

func (uc *UserController) GetEnergy(c *gin.Context) {
	uid := c.GetString("uid")

	var user models.User
	if err := config.DB.Where("id = ?", uid).First(&user).Error; err != nil {
		config.Logger.Errorw("获取用户信息失败", "error", err, "uid", uid)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"energy": user.Energy,
	})
}

func (uc *UserController) GetUser(c *gin.Context) {
	userID, exists := c.Get("uid")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户未认证"})
		return
	}
	
	userIDStr, ok := userID.(string)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "用户ID格式错误"})
		return
	}
	
	fmt.Printf("请求用户ID: %s\n", userIDStr)
	
	var user models.User
	if err := config.DB.Where("id = ?", userIDStr).First(&user).Error; err != nil {
		config.Logger.Errorw("数据库查询失败", 
			"error", err,
			"userID", userIDStr,
			"query", config.DB.ToSQL(func(tx *gorm.DB) *gorm.DB {
				return tx.Where("id = ?", userIDStr).First(&user)
			}),
		)
		c.JSON(http.StatusNotFound, gin.H{"error": "用户未找到"})
		return
	}

	fmt.Printf("查询到的用户数据: %+v\n", user)
	
	c.JSON(http.StatusOK, gin.H{
		"user": gin.H{
			"id":       user.ID,
			"username": user.Username,
			"email":    user.Email,
			"energy":   user.Energy,
		},
	})
}
