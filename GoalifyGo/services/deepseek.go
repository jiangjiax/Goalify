package services

import (
	"fmt"

	"github.com/tmc/langchaingo/llms"
	"github.com/tmc/langchaingo/llms/openai"
)

type DeepseekClient struct {
	DsChat llms.Model
}

func NewDeepseekClient(apiKey, apiEndpoint string) (*DeepseekClient, error) {
	v3, err := openai.New(
		openai.WithToken(apiKey),
		openai.WithBaseURL(apiEndpoint),
		openai.WithModel("deepseek/deepseek-v3"),
		openai.WithResponseFormat(&openai.ResponseFormat{
			Type: "json_object",
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create Deepseek client: %w", err)
	}

	return &DeepseekClient{
		DsChat: v3,
	}, nil
}
