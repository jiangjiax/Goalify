package routes

import (
	"GoalifyGo/controllers"
	"GoalifyGo/middleware"
	"GoalifyGo/services"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(r *gin.Engine, client *services.DeepseekClient) {
	authController := controllers.AuthController{}
	chatService := services.NewChatService(client)
	chatController := controllers.NewChatController(chatService)
	emotionController := controllers.EmotionController{}
	syncController := controllers.SyncController{}
	userController := controllers.UserController{}
	redeemController := controllers.RedeemController{}

	// 公开路由（无需认证）
	public := r.Group("/api/v1")
	{
		public.POST("/auth/wechat", authController.WechatLogin)
		public.POST("/auth/apple", authController.AppleLogin)
		public.POST("/auth/test-user", authController.CreateTestUser)
	}

	// 需要认证的路由
	private := r.Group("/api/v1")
	private.Use(middleware.AuthMiddleware()) // 应用认证中间件
	{
		// Chat 相关接口
		private.POST("/chat", chatController.SendMessage)
		private.POST("/analysis", chatController.AnalyzeReview)
		private.POST("/sync/emotions", emotionController.SyncEmotions)
		private.GET("/sync/updates", syncController.GetUpdates)
		private.GET("/user/energy", userController.GetEnergy)
		private.POST("/redeem", redeemController.RedeemCode)
		private.GET("/user", userController.GetUser)
		private.GET("/review-analyses", chatController.GetReviewAnalyses)
	}

	// 内部路由组（仅限服务器内部调用）
	internal := r.Group("/internal")
	//internal.Use(middleware.InternalAuthMiddleware()) // 添加内部认证中间件
	{
		//internal.GET("/user/add-energy", userController.AddEnergy)
		internal.GET("/redeem/generate", redeemController.CreateRedeemCode)
	}

	// 测试路由
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{"message": "pong"})
	})
}
