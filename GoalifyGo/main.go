package main

import (
	"GoalifyGo/config"
	"GoalifyGo/controllers"
	"GoalifyGo/middleware"
	"GoalifyGo/routes"
	"GoalifyGo/services"
	"context"
	"github.com/gin-gonic/gin"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// 初始化日志
	if err := config.InitLogger(); err != nil {
		log.Fatalf("无法初始化日志: %v", err)
	}
	defer config.Logger.Sync()

	// 加载配置
	conf, err := config.LoadConfig(".")
	if err != nil {
		log.Fatalf("无法加载配置: %v", err)
		return
	}

	// 初始化数据库
	if err := config.InitDB(conf); err != nil {
		log.Fatalf("无法初始化数据库: %v", err)
		return
	}

	// 初始化Redis
	if err := config.InitRedis(conf); err != nil {
		log.Fatalf("无法初始化Redis: %v", err)
		return
	}

	// 初始化Deepseek客户端
	deepseekClient, err := services.NewDeepseekClient(conf.DeepseekAPIKey, conf.DeepseekAPIEndpoint)
	if err != nil {
		log.Fatalf("无法初始化Deepseek客户端: %v", err)
	}

	// 创建ChatService
	chatService := services.NewChatService(deepseekClient)

	// 设置Gin模式
	if conf.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 创建Gin引擎
	r := gin.Default()

	// 设置中间件
	middleware.SetupMiddleware(r)

	// 注册路由
	routes.RegisterRoutes(r, deepseekClient)

	// 创建HTTP服务器
	srv := &http.Server{
		Addr:    ":" + conf.ServerPort,
		Handler: r,
	}

	// 在goroutine中启动服务器
	go func() {
		log.Printf("启动服务器，监听端口: %s", conf.ServerPort)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("服务器启动失败: %v", err)
		}
	}()

	// 等待中断信号以实现优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("正在关闭服务器...")

	// 创建超时上下文
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 优雅关闭服务器
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("服务器关闭失败: %v", err)
	}

	log.Println("服务器已关闭")

	// 在优雅关闭部分
	log.Println("正在等待所有后台任务完成...")
	chatController := controllers.NewChatController(chatService)
	chatController.Wait()
	chatService.Wait()
	log.Println("所有后台任务已完成")
}
