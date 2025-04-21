package models

import (
	"fmt"
	"time"
)

// SyncTasksRequest 任务同步请求结构体
type SyncTasksRequest struct {
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

// 添加验证和时区转换方法
func (r *SyncTasksRequest) ConvertToUTC() {
	if r.Deadline != nil {
		utcTime := r.Deadline.UTC()
		r.Deadline = &utcTime
	}
	if r.PlannedDate != nil {
		utcTime := r.PlannedDate.UTC()
		r.PlannedDate = &utcTime
	}
	r.LastModified = r.LastModified.UTC()
}

// SyncEmotionsRequest 情绪记录同步请求结构体
type SyncEmotionsRequest struct {
	ID               string    `json:"id"`
	EmotionType      string    `json:"emotionType"`
	Intensity        int       `json:"intensity"` // 1 消极 2 中性 3 积极
	Trigger          string    `json:"trigger"`
	UnhealthyBeliefs string    `json:"unhealthyBeliefs"`
	HealthyEmotion   string    `json:"healthyEmotion"`
	CopingStrategies string    `json:"copingStrategies"`
	RecordDate       time.Time `json:"recordDate"`
	LastModified     time.Time `json:"lastModified"`
}

func (r *SyncEmotionsRequest) ConvertToUTC() {
	r.RecordDate = r.RecordDate.UTC()
	r.LastModified = r.LastModified.UTC()
}

// SyncTimeRecordsRequest 时间记录同步请求结构体
type SyncTimeRecordsRequest struct {
	ID           string    `json:"id"`
	StartTime    time.Time `json:"startTime"`
	EndTime      time.Time `json:"endTime"`
	TaskID       string    `json:"taskId"` // 关联的任务ID
	LastModified time.Time `json:"lastModified"`
}

func (r *SyncTimeRecordsRequest) ConvertToUTC() {
	r.StartTime = r.StartTime.UTC()
	r.EndTime = r.EndTime.UTC()
	r.LastModified = r.LastModified.UTC()
}

// ReviewAnalysisRequest 复盘分析请求结构体
type ReviewAnalysisRequest struct {
	Period     string               `json:"period" binding:"required"` // day, week, month
	StartDate  time.Time            `json:"startDate" binding:"required"`
	EndDate    time.Time            `json:"endDate" binding:"required"`
	TimeRecord []TimeRecordWithTask `json:"timeRecords"`
}

func (r *ReviewAnalysisRequest) Validate() error {
	validPeriods := map[string]bool{"day": true, "week": true, "month": true}
	if !validPeriods[r.Period] {
		return fmt.Errorf("invalid period, must be one of: day, week, month")
	}

	// 将时间转换为 UTC
	r.StartDate = r.StartDate.UTC()
	r.EndDate = r.EndDate.UTC()

	if r.StartDate.After(r.EndDate) {
		return fmt.Errorf("start date must be before end date")
	}
	return nil
}

// TimeRecordWithTask 包含时间记录和任务信息的结构体
type TimeRecordWithTask struct {
	TaskID    string `json:"taskId"`
	Title     string `json:"title"`
	TotalTime int    `json:"totalTime"` // 秒数
}

// 添加子任务同步请求结构体
type SyncSubtasksRequest struct {
	ID           string    `json:"id"`
	Title        string    `json:"title"`
	IsCompleted  bool      `json:"isCompleted"`
	TaskID       string    `json:"taskId"`
	LastModified time.Time `json:"lastModified"`
}

// 添加时区转换方法
func (r *SyncSubtasksRequest) ConvertToUTC() {
	r.LastModified = r.LastModified.UTC()
}
