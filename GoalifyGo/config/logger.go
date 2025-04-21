// 新增日志配置
package config

import (
    "fmt"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
    "gopkg.in/natefinch/lumberjack.v2"
    "os"
    "time"
)

var Logger *zap.SugaredLogger

func InitLogger() error {
    // 配置日志输出
    encoderConfig := zap.NewProductionEncoderConfig()
    encoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
    
    // 文件日志核心
    fileCore := zapcore.NewCore(
        zapcore.NewJSONEncoder(encoderConfig),
        zapcore.AddSync(&lumberjack.Logger{
            Filename:   fmt.Sprintf("logs/app_%s.log", time.Now().Format("2006-01-02")), // 按日期命名
            MaxSize:    100, // MB
            MaxBackups: 30,
            MaxAge:     90, // days
        }),
        zap.InfoLevel,
    )

    // 控制台日志核心
    consoleCore := zapcore.NewCore(
        zapcore.NewConsoleEncoder(encoderConfig),
        zapcore.AddSync(os.Stdout),
        zap.DebugLevel,
    )

    // 组合多个日志核心
    core := zapcore.NewTee(fileCore, consoleCore)
    
    logger := zap.New(core, zap.AddCaller(), zap.AddStacktrace(zap.ErrorLevel))
    Logger = logger.Sugar()
    return nil
} 