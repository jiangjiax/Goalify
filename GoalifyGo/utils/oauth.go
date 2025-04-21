package utils

import (
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"GoalifyGo/config"
	"github.com/golang-jwt/jwt/v4"
)

type WechatAccessTokenResponse struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	OpenID       string `json:"openid"`
}

type WechatUserInfo struct {
	OpenID       string `json:"openid"`
	Nickname     string `json:"nickname"`
	HeadImageURL string `json:"headimgurl"`
}

var appleClientID string

func init() {
	config, err := config.LoadConfig(".")
	if err != nil {
		panic("Failed to load config: " + err.Error())
	}
	appleClientID = config.AppleClientID
}

func GetWechatAccessToken(code string) (string, string, error) {
	// TODO: 实现微信access_token获取逻辑
	// 这里应该调用微信API获取access_token
	// 返回值: accessToken, openID, error
	return "", "", fmt.Errorf("未实现的微信access_token获取逻辑")
}

func GetWechatUserInfo(accessToken, openID string) (*WechatUserInfo, error) {
	// TODO: 实现微信用户信息获取逻辑
	// 这里应该调用微信API获取用户信息
	return nil, fmt.Errorf("未实现的微信用户信息获取逻辑")
}

// VerifyAppleIdentityToken 验证苹果的 identityToken 并返回用户标识
func VerifyAppleIdentityToken(tokenString string) (string, error) {
	// 1. 解析 token 的头部，获取 kid 和 alg
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, jwt.MapClaims{})
	if err != nil {
		return "", fmt.Errorf("解析 token 失败: %v", err)
	}

	kid := token.Header["kid"].(string)
	alg := token.Header["alg"].(string)

	// 2. 获取苹果的公钥
	publicKey, err := getApplePublicKey(kid)
	if err != nil {
		return "", fmt.Errorf("获取苹果公钥失败: %v", err)
	}

	// 3. 验证 token 的签名
	parsedToken, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if token.Method.Alg() != alg {
			return nil, fmt.Errorf("不支持的签名算法: %v", token.Header["alg"])
		}
		return publicKey, nil
	})
	if err != nil {
		return "", fmt.Errorf("验证 token 签名失败: %v", err)
	}

	// 4. 验证 token 的 claims
	claims, ok := parsedToken.Claims.(jwt.MapClaims)
	if !ok || !parsedToken.Valid {
		return "", errors.New("无效的 token")
	}

	// 检查 issuer
	if claims["iss"] != "https://appleid.apple.com" {
		return "", errors.New("无效的签发者")
	}

	// 检查 audience
	if claims["aud"] != appleClientID {
		return "", errors.New("无效的受众")
	}

	// 检查过期时间
	exp, ok := claims["exp"].(float64)
	if !ok || time.Now().Unix() > int64(exp) {
		return "", errors.New("token 已过期")
	}

	// 5. 返回用户的唯一标识
	userID, ok := claims["sub"].(string)
	if !ok {
		return "", errors.New("无法获取用户标识")
	}

	return userID, nil
}

// getApplePublicKey 获取苹果的公钥
func getApplePublicKey(kid string) (*rsa.PublicKey, error) {
	// 1. 从苹果的 JWKS 端点获取公钥集合
	resp, err := http.Get("https://appleid.apple.com/auth/keys")
	if err != nil {
		return nil, fmt.Errorf("获取苹果公钥失败: %v", err)
	}
	defer resp.Body.Close()

	var jwks struct {
		Keys []struct {
			Kid string `json:"kid"`
			Alg string `json:"alg"`
			Use string `json:"use"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("解析苹果公钥失败: %v", err)
	}

	// 2. 查找匹配的 kid
	var key *rsa.PublicKey
	for _, k := range jwks.Keys {
		if k.Kid == kid {
			// 3. 解析公钥
			nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
			if err != nil {
				return nil, fmt.Errorf("解析公钥 n 失败: %v", err)
			}

			eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
			if err != nil {
				return nil, fmt.Errorf("解析公钥 e 失败: %v", err)
			}

			e := int(new(big.Int).SetBytes(eBytes).Int64())
			key = &rsa.PublicKey{
				N: new(big.Int).SetBytes(nBytes),
				E: e,
			}
			break
		}
	}

	if key == nil {
		return nil, errors.New("未找到匹配的公钥")
	}

	return key, nil
}
