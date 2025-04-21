package utils

import (
	"GoalifyGo/config"
	"github.com/google/uuid"
)

func GenerateID() string {
	id := uuid.New().String()
	config.Logger.Debugw("生成新ID", "id", id)
	return id
}
