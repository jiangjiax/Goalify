package controllers

import (
	"GoalifyGo/config"
	"GoalifyGo/models"
	"GoalifyGo/utils"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// AuthController 认证控制器
type AuthController struct{}

// ThirdPartyLoginRequest 新增登录请求结构体
type ThirdPartyLoginRequest struct {
	Code  string `json:"code" binding:"required"` // 授权码
	State string `json:"state"`                   // 状态参数
}

// WechatLogin 微信登录
func (ac *AuthController) WechatLogin(c *gin.Context) {
	var req ThirdPartyLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 获取微信access_token
	accessToken, openID, err := utils.GetWechatAccessToken(req.Code)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "微信登录失败"})
		return
	}

	// 获取用户信息
	wechatUser, err := utils.GetWechatUserInfo(accessToken, openID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户信息失败"})
		return
	}

	// 查找或创建用户
	var user models.User
	result := config.DB.Where("provider = ? AND provider_id = ?", "wechat", openID).First(&user)
	if result.Error != nil {
		// 创建新用户
		user = models.User{
			ID:         utils.GenerateID(), // 确保这里生成了 ID
			Provider:   "wechat",
			ProviderID: openID,
			Avatar:     wechatUser.HeadImageURL,
			Username:   wechatUser.Nickname,
			CreatedAt:  time.Now(),
			Energy:     20, // 默认20点能量值
		}
		if err := config.DB.Create(&user).Error; err != nil {
			config.Logger.Errorw("用户创建失败",
				"error", err,
				"provider", "wechat",
				"openID", openID,
			)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "用户创建失败"})
			return
		}
		config.Logger.Infow("用户创建成功",
			"userID", user.ID,
			"provider", "wechat",
		)
	}

	log.Printf("User ID before token generation: %s", user.ID)
	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       user.ID,
			"username": user.Username,
			"avatar":   user.Avatar,
		},
	})
}

// AppleLogin 苹果登录
func (ac *AuthController) AppleLogin(c *gin.Context) {
	var req struct {
		IdentityToken string `json:"identity_token" binding:"required"`
		Email         string `json:"email"` // 苹果首次登录会返回邮箱
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 验证苹果身份令牌
	appleID, err := utils.VerifyAppleIdentityToken(req.IdentityToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "身份验证失败"})
		return
	}

	// 查找或创建用户
	var user models.User
	result := config.DB.Where("provider = ? AND provider_id = ?", "apple", appleID).First(&user)
	if result.Error != nil {
		user = models.User{
			ID:         utils.GenerateID(), // 确保这里生成了 ID
			Provider:   "apple",
			ProviderID: appleID,
			Email:      req.Email, // 苹果首次登录会返回邮箱
		}
		if err := config.DB.Create(&user).Error; err != nil {
			config.Logger.Errorw("用户创建失败",
				"error", err,
				"provider", "apple",
				"appleID", appleID,
			)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "用户创建失败"})
			return
		}
		config.Logger.Infow("新用户创建成功",
			"userID", user.ID,
			"provider", "apple",
		)
	} else {
		log.Printf("找到现有用户，ID: %s", user.ID)
	}

	// 生成JWT
	token, err := utils.GenerateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       user.ID,
			"username": user.GetDisplayName(),
			"email":    user.Email,
			"avatar":   user.Avatar,
		},
	})
}

// CreateTestUser 创建测试用户
func (ac *AuthController) CreateTestUser(c *gin.Context) {
	testUser := models.User{
		ID:         utils.GenerateID(), // 使用新的 ID 生成策略
		Username:   "test_user_1",
		Email:      "test_1@example.com",
		IsTestUser: true,
	}

	if err := config.DB.Create(&testUser).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建测试用户失败"})
		return
	}

	// 生成 JWT
	token, err := utils.GenerateToken(testUser.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "令牌生成失败"})
		return
	}

	config.Logger.Infow("创建测试用户",
		"userID", testUser.ID,
		"username", testUser.Username,
	)

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       testUser.ID,
			"username": testUser.Username,
			"email":    testUser.Email,
		},
	})
}
