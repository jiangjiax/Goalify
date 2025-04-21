package models

import "time"

// SyncUpdatesResponse 同步更新响应结构体
type SyncUpdatesResponse struct {
	Emotions []EmotionResponse `json:"emotions"`
}

// TaskResponse 任务响应结构体
type TaskResponse struct {
	ID           string     `json:"id"`
	Title        string     `json:"title"`
	IsCompleted  bool       `json:"isCompleted"`
	Notes        string     `json:"notes"`
	Deadline     *time.Time `json:"deadline"`
	PlannedDate  *time.Time `json:"plannedDate"`
	Difficulty   int        `json:"difficulty"`
	Quadrant     string     `json:"quadrant"`
	RepeatType   string     `json:"repeatType"`
	LastModified time.Time  `json:"lastModified"`
}

// EmotionResponse 情绪记录响应结构体
type EmotionResponse struct {
	ID               string    `json:"id"`
	EmotionType      string    `json:"emotionType"`
	Intensity        int       `json:"intensity"`
	Trigger          string    `json:"trigger"`
	UnhealthyBeliefs string    `json:"unhealthyBeliefs"`
	HealthyEmotion   string    `json:"healthyEmotion"`
	CopingStrategies string    `json:"copingStrategies"`
	RecordDate       time.Time `json:"recordDate"`
	LastModified     time.Time `json:"lastModified"`
}

// TimeRecordResponse 时间记录响应结构体
type TimeRecordResponse struct {
	ID           string    `json:"id"`
	StartTime    time.Time `json:"startTime"`
	EndTime      time.Time `json:"endTime"`
	TaskID       string    `json:"taskId"`
	LastModified time.Time `json:"lastModified"`
}

// UserResponse 用户响应结构体
type UserResponse struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
	Email    string `json:"email"`
	Energy   int    `json:"energy"`
}

// SubtaskResponse 子任务响应结构体
type SubtaskResponse struct {
	ID           string    `json:"id"`
	Title        string    `json:"title"`
	IsCompleted  bool      `json:"isCompleted"`
	TaskID       string    `json:"taskId"`
	LastModified time.Time `json:"lastModified"`
}
