# LLM API Comparison for Computer Control (2026)

Comprehensive comparison of major LLM APIs and their capabilities for computer control applications, updated January 2026.

---

## 1. OpenAI GPT-4/ChatGPT API

### API Endpoint
- **Base URL**: `https://api.openai.com/v1/chat/completions`
- **Chat Completions**: `/v1/chat/completions`
- **Realtime API**: Available for bidirectional audio streaming

### Authentication
- **Method**: Bearer token authentication
- **Format**: `-H "Authorization: Bearer $OPENAI_API_KEY"`
- **Additional Headers**: Optional Organization ID and Project ID headers

### Vision Capabilities
- **Support**: Full multimodal support (images, PDFs, text)
- **PDF Support**: Native PDF input via URL or upload
- **Image Fine-tuning**: Available for improving vision capabilities
- **Integration**: Vision integrated into GPT-4o, GPT-4.1, and GPT-4.5 models (not a separate model)
- **Max Images**: Multiple images per request supported

### Streaming Support
- **Server-Sent Events (SSE)**: Yes
- **Realtime API**: Low-latency bidirectional audio streaming (GA)
- **Voice Activity Detection**: Supported with interruption handling
- **Function Calling**: Available during streaming

### Rate Limits
- **Scale Tier System**: Enterprise customers can purchase guaranteed throughput
  - GPT-4.1: 30k input tokens/min per unit ($110/day), 2.5k output tokens/min per unit ($36/day)
  - Minimum 30-day commitment per unit
- **Priority Processing**: Available at premium rates
- **Standard Tier**: Usage-based limits (varies by account tier)

### Pricing (Per Million Tokens)
- **GPT-4.5** (Research Preview): Higher pricing than GPT-4.1 (exact rates TBD)
- **GPT-4.1**: $2.00 input / $8.00 output (up to 1M context)
- **GPT-4o**: $2.50 input / $10.00 output (up to 128K context)
- **Batch API**: 50% discount (e.g., GPT-5: $0.625 input / $5.00 output)
- **Prompt Caching**: 50-90% savings depending on model

### Special Features for Computer Control
- **Computer-Using Agent (CUA)**: Dedicated model for GUI interaction
  - Combines GPT-4o vision with advanced reasoning via reinforcement learning
  - Trained to interact with buttons, menus, text fields, and screen elements
  - API access in development (not yet GA as of Jan 2026)
- **Agent Capabilities**: GPT-4.1 significantly improved for agentic tasks
  - 54.6% completion rate on SWE-bench Verified (vs 33.2% for GPT-4o)
  - Excellent for autonomous software engineering tasks
- **Responses API**: Enhanced agent reliability for complex tasks
- **Operator**: Browser-based agent (not yet in API)

---

## 2. Anthropic Claude API

### API Endpoint
- **Base URL**: `https://api.anthropic.com/v1/messages`
- **Messages API**: `/v1/messages`
- **Alternative Platforms**: AWS Bedrock, Google Vertex AI

### Authentication
- **Method**: API key header
- **Format**: `x-api-key` header
- **Key Management**: Generate keys in Account Settings
- **SDKs**: Official Python and TypeScript SDKs available

### Vision Capabilities
- **Support**: All Claude 4.5 models support text and image input
- **Input Methods**:
  - Base64 encoding (inline)
  - Files API for larger images
- **Limits**:
  - 100 images per request
  - 32MB request size limit (standard endpoints)
- **Use Cases**: Charts, graphs, technical diagrams, reports, visual assets

### Streaming Support
- **Server-Sent Events (SSE)**: Yes, via `"stream": true` parameter
- **Time to First Token**: Usually under 500ms
- **SDK Support**:
  - Python: `client.messages.stream()`
  - TypeScript: Similar streaming interface
- **Platform Availability**: Streaming works on Anthropic API, AWS Bedrock, and Vertex AI

### Rate Limits
- **Tiered System**: 4 tiers based on deposit amount
  - Tier 1: $5 deposit minimum
  - Tier 2: $40 deposit
  - Tier 3: $200 deposit
  - Tier 4: $400+ deposit
- **Metrics**: Requests per minute (RPM), Input tokens per minute (ITPM), Output tokens per minute (OTPM)
- **Algorithm**: Token bucket with continuous replenishment
- **Spend Limits**: Monthly spend limits per tier
- **Cache Optimization**: Uncached tokens only count toward ITPM limits

### Pricing (Per Million Tokens)
- **Claude Opus 4.5**: $5 input / $25 output (most capable)
- **Claude Sonnet 4.5**: $3 input / $15 output (balanced)
  - Long context (>200K tokens): $6 input / $22.50 output (1M context window)
- **Claude Haiku 4.5**: $1 input / $5 output (fastest)
- **Legacy Models**: Claude Opus 4.1 at $15 input / $75 output
- **Batch API**: 50% discount on input and output tokens
- **Prompt Caching**:
  - Cache read: 0.1x base input price
  - 5-minute default, 1-hour cache duration available

### Special Features for Computer Control
- **Computer Use API**: Industry-leading capability
  - Available with Claude Sonnet 3.5 and Claude Opus 4.5
  - Direct screen interaction and GUI control
  - Integrated with Messages API and streaming
- **Tool Use**: Native function calling support
- **Long Context**: 1M token context window (Claude Sonnet 4.5 with premium pricing)
- **Enterprise Features**: Optimized for agents, coding, and workflows

---

## 3. Google Gemini API

### API Endpoint
- **Base URL**: `https://generativelanguage.googleapis.com`
- **Generate Content**: `/generateContent`
- **Stream Generate**: `/streamGenerateContent`
- **Bidirectional Stream**: `/BidiGenerateContent` (WebSocket)
- **Batch Processing**: `/batchGenerateContent`

### Authentication
- **Method**: API key header
- **Format**: `x-goog-api-key` header
- **Key Creation**: Via Google AI Studio
- **Platform**: Google AI Studio API

### Vision Capabilities
- **Multimodal Foundation**: Built multimodal from ground up
- **Input Methods**:
  - Inline image data (files under 20MB total)
  - File API for larger files
- **Capabilities**:
  - Image captioning
  - Classification
  - Visual question answering
  - Object detection (Gemini 2.0+)
  - Segmentation (Gemini 2.5+)
- **Gemini 3 Vision Enhancement**:
  - `media_resolution` parameter for granular control
  - Higher resolutions improve text reading and detail identification
  - Trade-off: Higher token usage and latency

### Streaming Support
- **SSE Streaming**: `/streamGenerateContent` endpoint
- **Bidirectional Streaming**: `/BidiGenerateContent` (WebSocket-based, real-time)
- **Gemini Live API**:
  - Low-latency voice and video interactions
  - Continuous audio/video/text stream processing
  - Barge-in support (user interruptions)
  - Text streaming for incremental responses

### Rate Limits
- **Project-Based**: Applied per project, not per API key
- **Free Tier** (as of Jan 2026):
  - 5-15 requests per minute (model dependent)
  - 250,000 tokens per minute
  - 1,000 requests per day
- **Paid Tier**: Higher limits for production applications
- **Viewing**: Check limits in Google AI Studio

### Pricing (Per Million Tokens)
- **Gemini 3 Pro Preview**:
  - Standard (≤200K tokens): $2.00 input / $12.00 output
  - Long context (>200K tokens): $4.00 input / $18.00 output
  - Currently free tier waived during preview
- **Gemini 2.5 Pro**:
  - Standard (≤200K tokens): $1.25 input / $10 output
  - Long context (>200K tokens): 2x pricing
- **Gemini 2.5 Flash**: $0.075 - $0.60 per million tokens
- **Gemini 2.5 Flash-Lite**: $0.10 input / $0.40 output
- **Gemini 2.0 Flash-Lite**: $0.075 input / $0.30 output
- **Batch Processing**: Gemini 2.5 Pro at $0.625 input / $5 output (50% discount)
- **Context Caching**: Up to 75% cost reduction for large repeated prompts
- **Last Updated**: January 22, 2026

### Special Features for Computer Control
- **Gemini Live API**: Real-time voice and video agent capabilities
  - Unified multimodal processing (audio, text, visual)
  - Affective dialogue (tone matching)
  - Tool integration (function calling, Google Search)
  - Enterprise-grade for mission-critical workflows
- **Agent Building**: Native support for AI agent development
- **Function Calling**: Available during streaming
- **Video Understanding**: Process continuous video streams with spoken input
- **Shopping/Retail Agents**: Optimized for e-commerce use cases

---

## 4. xAI Grok API

### API Endpoint
- **Base URL**: `https://api.x.ai/v1`
- **Alternative**: `https://api.grok.xai.com/v1/completions`
- **Completions**: `/v1/completions`

### Authentication
- **Method**: API key via Authorization header
- **Format**: `Authorization: Bearer $XAI_API_KEY`
- **Environment Variable**: Defaults to `XAI_API_KEY`
- **Key Creation**: Via xAI Console

### Vision Capabilities
- **Vision Models**:
  - `grok-2-vision-1212`
  - `grok-vision-beta`
- **Support**: Image input with vision models
- **Format**: Same as OpenAI-compatible format
- **Capabilities**: Image-based tasks, visual understanding with sharp insights

### Streaming Support
- **Standard Streaming**: Yes, server-sent events
- **Verbose Streaming**: Real-time tool call visibility
  - `include=["verbose_streaming"]` parameter
  - Shows server-side tool calls as they execute
  - Example: View tool name and arguments during streaming
- **Grok Voice Agent API**:
  - Real-time voice interaction
  - Low-latency bidirectional audio
  - Partnership with LiveKit and Voximplant for production calls

### Rate Limits
- **Model-Specific**: Each model has different limits
- **Console Access**: View team rate limits at xAI Console Models Page
- **Rate Limit Tiers**: Varies by account type

### Pricing (Per Million Tokens)
- **Grok 4.1 Fast**: $0.20 input / $0.50 output (most cost-effective)
- **Grok Code Fast**: $0.20 input / $1.50 output
- **Grok 3 Mini**: $0.30 input / $0.50 output
- **Grok 3**: $3 input / $15 output
- **Grok 4**: $3 input / $15 output
- **Grok 2 Vision**: $2 input / $10 output
- **Cache-Read**: ~$0.05 per million tokens
- **Tool Costs**: Web Search, X Search, Code Execution, Document Search at $5 per 1,000 calls
- **Billing**: Prepaid credits or monthly invoiced, no subscription required

### Special Features for Computer Control
- **Agentic Server-Side Tool Calling**:
  - Autonomous exploration, search, and code execution
  - Model manages entire reasoning and tool-execution loop
  - Multi-turn, multi-tool parallel invocation
  - All tools run on xAI infrastructure
- **Agent Tools API** (FREE):
  - Real-time X search
  - Web search
  - Remote code execution
  - Collections search
  - MCP (Model Context Protocol) support
- **Context Window**: 2 million tokens across all models
- **Real-Time Data**: Access to live X platform data
- **Verbose Streaming**: Debug and monitor agent tool usage in real-time

---

## 5. Vision API: Exact Request/Response Formats for Screenshot Analysis

This section provides copy-paste-ready request formats for sending a screenshot image (base64-encoded) to each provider and parsing the response. This is the reference for building a unified multi-LLM vision interface.

---

### Vision Comparison Quick Reference

| Feature | OpenAI | Anthropic Claude | Google Gemini |
|---------|--------|------------------|---------------|
| **Vision Endpoint** | `https://api.openai.com/v1/chat/completions` | `https://api.anthropic.com/v1/messages` | `https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent` |
| **Auth Header** | `Authorization: Bearer $KEY` | `x-api-key: $KEY` | `x-goog-api-key: $KEY` |
| **Image Content Type** | `"type": "image_url"` | `"type": "image"` | `"inline_data"` in `parts[]` |
| **Base64 Format** | Data URI: `data:image/png;base64,...` | Raw base64 string + `media_type` field | Raw base64 string + `mime_type` field |
| **Best Vision Model** | `gpt-4o` / `gpt-4.1` | `claude-sonnet-4-5-20250929` | `gemini-2.5-flash` |
| **Max Images/Request** | 10 | 20 | 3,600 |
| **Max Image Size** | Not specified (token-based) | 3.75 MB, 8000x8000 px | 20 MB total request |
| **Response Text Path** | `choices[0].message.content` | `content[0].text` | `candidates[0].content.parts[0].text` |
| **Supported Formats** | PNG, JPEG, GIF, WebP | PNG, JPEG, GIF, WebP | PNG, JPEG, WebP, GIF |
| **Detail Control** | `detail` param (low/high/auto) | Automatic | `media_resolution` param (Gemini 3) |
| **Image Token Cost** | 65-6240 tokens (detail-dependent) | ~pixel_area / constant | 258-1120 tokens (resolution-dependent) |

---

### 5.1 OpenAI GPT Vision Request Format

#### Endpoint
```
POST https://api.openai.com/v1/chat/completions
```

#### Required Headers
```
Content-Type: application/json
Authorization: Bearer $OPENAI_API_KEY
```

#### Vision-Capable Model Names (API IDs)
| Model | API ID | Notes |
|-------|--------|-------|
| GPT-5.2 | `gpt-5.2` | Latest flagship |
| GPT-5.1 | `gpt-5.1` | Previous flagship |
| GPT-5 | `gpt-5` | Flagship with thinking |
| GPT-4.1 | `gpt-4.1` | Best non-reasoning, 1M context |
| GPT-4.1 Mini | `gpt-4.1-mini` | Cost-effective |
| GPT-4.1 Nano | `gpt-4.1-nano` | Cheapest |
| GPT-4o | `gpt-4o` | Omni model (audio+vision) |
| GPT-4o Mini | `gpt-4o-mini` | Legacy cost-effective |
| o4-mini | `o4-mini-2025-04-16` | Reasoning + vision |
| o3 | `o3-2025-04-16` | Strong visual reasoning |

#### Full curl Example (Base64 Screenshot)
```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Analyze this screenshot. Describe all UI elements, their positions, and any text visible on screen."
          },
          {
            "type": "image_url",
            "image_url": {
              "url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
              "detail": "high"
            }
          }
        ]
      }
    ],
    "max_tokens": 4096
  }'
```

#### JSON Request Body Structure
```json
{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "system",
      "content": "You are a computer vision assistant that analyzes screenshots."
    },
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "What do you see in this screenshot?"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,<BASE64_ENCODED_PNG_DATA>",
            "detail": "high"
          }
        }
      ]
    }
  ],
  "max_tokens": 4096,
  "temperature": 0.2
}
```

#### Response Format
```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1706000000,
  "model": "gpt-4o-2024-11-20",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The screenshot shows a macOS desktop with..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 1250,
    "completion_tokens": 350,
    "total_tokens": 1600
  },
  "system_fingerprint": "fp_abc123"
}
```

#### Extract Response Text
```
response["choices"][0]["message"]["content"]
```

#### Alternative: OpenAI Responses API (Newer)
```bash
curl https://api.openai.com/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4.1",
    "input": [
      {
        "role": "user",
        "content": [
          {
            "type": "input_text",
            "text": "Analyze this screenshot."
          },
          {
            "type": "input_image",
            "image_url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
          }
        ]
      }
    ]
  }'
```

#### Image Detail Parameter
| Value | Behavior | Token Cost |
|-------|----------|------------|
| `"low"` | Fixed low-res processing | 65 tokens |
| `"high"` | Tiled high-res processing | 129 tokens/tile + 4160-6240 extra |
| `"auto"` | Model decides (default) | Varies |

---

### 5.2 Anthropic Claude Vision Request Format

#### Endpoint
```
POST https://api.anthropic.com/v1/messages
```

#### Required Headers
```
content-type: application/json
x-api-key: $ANTHROPIC_API_KEY
anthropic-version: 2023-06-01
```

#### Vision-Capable Model Names (API IDs)
| Model | API ID | Notes |
|-------|--------|-------|
| Claude Opus 4.5 | `claude-opus-4-5-20251124` | Most intelligent |
| Claude Sonnet 4.5 | `claude-sonnet-4-5-20250929` | Best balance (recommended) |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Fastest, cheapest |
| Claude Opus 4.1 | `claude-opus-4-1-20250805` | Previous premium |
| Claude Opus 4 | `claude-opus-4-20250514` | Previous generation |
| Claude Sonnet 4 | `claude-sonnet-4-20250514` | Previous mid-tier |

All current Claude models support vision. Legacy Claude 3.x models are deprecated/retired.

#### Full curl Example (Base64 Screenshot)
```bash
# Encode screenshot
IMAGE_BASE64=$(base64 -i screenshot.png)

curl https://api.anthropic.com/v1/messages \
  --header "x-api-key: $ANTHROPIC_API_KEY" \
  --header "anthropic-version: 2023-06-01" \
  --header "content-type: application/json" \
  --data '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 4096,
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "image",
            "source": {
              "type": "base64",
              "media_type": "image/png",
              "data": "'"$IMAGE_BASE64"'"
            }
          },
          {
            "type": "text",
            "text": "Analyze this screenshot. Describe all UI elements, their positions, and any text visible on screen."
          }
        ]
      }
    ]
  }'
```

#### JSON Request Body Structure
```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 4096,
  "system": "You are a computer vision assistant that analyzes screenshots.",
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/png",
            "data": "<BASE64_ENCODED_PNG_DATA>"
          }
        },
        {
          "type": "text",
          "text": "What do you see in this screenshot?"
        }
      ]
    }
  ]
}
```

#### Alternative: URL-Based Image Input
```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 4096,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "url",
            "url": "https://example.com/screenshot.png"
          }
        },
        {
          "type": "text",
          "text": "Describe this image."
        }
      ]
    }
  ]
}
```

#### Response Format
```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "The screenshot shows a macOS desktop with..."
    }
  ],
  "model": "claude-sonnet-4-5-20250929",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 1520,
    "output_tokens": 380
  }
}
```

#### Extract Response Text
```
response["content"][0]["text"]
```

#### Image Constraints
- Max 20 images per request
- Each image: max 3.75 MB file size
- Max dimensions: 8,000 x 8,000 pixels
- Supported formats: `image/png`, `image/jpeg`, `image/gif`, `image/webp`
- Images are ephemeral (not stored beyond request duration)
- Best practice: place images before text prompts about them

---

### 5.3 Google Gemini Vision Request Format

#### Endpoint
```
POST https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent
```

For example:
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
```

#### Required Headers
```
Content-Type: application/json
x-goog-api-key: $GEMINI_API_KEY
```

#### Vision-Capable Model Names (API IDs)
| Model | API ID | Notes |
|-------|--------|-------|
| Gemini 3 Pro | `gemini-3-pro-preview` | Latest, 1M context |
| Gemini 3 Flash | `gemini-3-flash-preview` | Latest fast model |
| Gemini 2.5 Pro | `gemini-2.5-pro` | Stable production |
| Gemini 2.5 Flash | `gemini-2.5-flash` | Stable fast (recommended) |
| Gemini 2.5 Flash-Lite | `gemini-2.5-flash-lite` | Budget option |
| Gemini 2.0 Flash | `gemini-2.0-flash` | Legacy (deprecated March 2026) |

All Gemini 2.0+ models are vision-capable (natively multimodal).

#### Full curl Example (Base64 Screenshot)
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "inline_data": {
              "mime_type": "image/png",
              "data": "'"$(base64 -i screenshot.png)"'"
            }
          },
          {
            "text": "Analyze this screenshot. Describe all UI elements, their positions, and any text visible on screen."
          }
        ]
      }
    ],
    "generationConfig": {
      "temperature": 0.2,
      "maxOutputTokens": 4096
    }
  }'
```

#### JSON Request Body Structure
```json
{
  "contents": [
    {
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "<BASE64_ENCODED_PNG_DATA>"
          }
        },
        {
          "text": "What do you see in this screenshot?"
        }
      ]
    }
  ],
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a computer vision assistant that analyzes screenshots."
      }
    ]
  },
  "generationConfig": {
    "temperature": 0.2,
    "maxOutputTokens": 4096
  }
}
```

#### With System Instruction and Multi-Turn
```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "<BASE64_ENCODED_PNG_DATA>"
          }
        },
        {
          "text": "What do you see?"
        }
      ]
    }
  ],
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a computer vision assistant."
      }
    ]
  },
  "generationConfig": {
    "temperature": 0.2,
    "maxOutputTokens": 4096
  }
}
```

#### Response Format
```json
{
  "candidates": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "text": "The screenshot shows a macOS desktop with..."
          }
        ]
      },
      "finishReason": "STOP",
      "safetyRatings": [
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "probability": "NEGLIGIBLE"
        }
      ]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 1300,
    "candidatesTokenCount": 400,
    "totalTokenCount": 1700
  }
}
```

#### Extract Response Text
```
response["candidates"][0]["content"]["parts"][0]["text"]
```

#### Gemini 3 Media Resolution Control
```json
{
  "contents": [
    {
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "<BASE64_DATA>",
            "media_resolution": "media_resolution_high"
          }
        },
        {
          "text": "Read all text in this screenshot."
        }
      ]
    }
  ]
}
```

| Resolution | Token Cost | Use Case |
|-----------|------------|----------|
| `media_resolution_low` | 280 tokens | Quick classification |
| `media_resolution_medium` | 560 tokens | General analysis |
| `media_resolution_high` | 1120 tokens | Fine text, small details |

#### Image Constraints
- Max 20 MB total request size (inline)
- Max 3,600 images per request (Gemini 2.5+)
- Use File API for larger files
- Supported formats: `image/png`, `image/jpeg`, `image/webp`, `image/gif`

---

### 5.4 Unified Interface: Key Differences for Implementation

When building a unified multi-LLM vision interface, these are the critical structural differences to abstract:

#### Message Structure Mapping

```
OpenAI:     messages[].content[] -> { type: "image_url", image_url: { url: "data:..." } }
Claude:     messages[].content[] -> { type: "image", source: { type: "base64", media_type: "...", data: "..." } }
Gemini:     contents[].parts[]   -> { inline_data: { mime_type: "...", data: "..." } }
```

#### System Prompt Location

```
OpenAI:     messages[0] with role: "system"
Claude:     Top-level "system" field
Gemini:     Top-level "systemInstruction" field
```

#### Authentication Pattern

```
OpenAI:     Authorization: Bearer $KEY
Claude:     x-api-key: $KEY  +  anthropic-version: 2023-06-01
Gemini:     x-goog-api-key: $KEY  (or query param ?key=$KEY)
```

#### Base64 Encoding Differences

```
OpenAI:     Requires data URI prefix: "data:image/png;base64,<data>"
Claude:     Raw base64 string, media_type in separate field
Gemini:     Raw base64 string, mime_type in separate field
```

#### Response Text Extraction

```
OpenAI:     response.choices[0].message.content        (string)
Claude:     response.content[0].text                    (string from content block)
Gemini:     response.candidates[0].content.parts[0].text (string from parts)
```

#### Token Usage Fields

```
OpenAI:     usage.prompt_tokens / usage.completion_tokens / usage.total_tokens
Claude:     usage.input_tokens / usage.output_tokens
Gemini:     usageMetadata.promptTokenCount / usageMetadata.candidatesTokenCount / usageMetadata.totalTokenCount
```

#### Stop Reason Values

```
OpenAI:     finish_reason: "stop" | "length" | "content_filter" | "tool_calls"
Claude:     stop_reason: "end_turn" | "max_tokens" | "stop_sequence" | "tool_use"
Gemini:     finishReason: "STOP" | "MAX_TOKENS" | "SAFETY" | "RECITATION"
```

---

## 6. Streaming SSE Wire Formats (for Swift URLSession Implementation)

This section provides the exact raw SSE (Server-Sent Events) line formats each provider sends over the wire. These are the literal bytes your `URLSessionDataDelegate` will receive, and you must parse them accordingly.

**Common SSE parsing logic for all providers:**
- Lines are delimited by `\n\n` (double newline) between events
- Each event has one or more fields: `event:`, `data:`, `id:`, `retry:`
- Lines starting with `:` are comments (ignore them)
- Empty `data:` lines should be ignored
- You accumulate `data:` lines until you hit a blank line, then dispatch the event

---

### 6.1 OpenAI Streaming Format

**Request:** Add `"stream": true` to the normal chat completions JSON body. Optionally add `"stream_options": {"include_usage": true}` to get token counts in the final chunk.

**Content-Type returned:** `text/event-stream`

**Raw SSE output (exactly as received over the wire):**

```
data: {"id":"chatcmpl-A8dyC7f6pKkQ516qqRHK6ep7Z3yG9","object":"chat.completion.chunk","created":1726623632,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_483d39d857","choices":[{"index":0,"delta":{"role":"assistant","content":"","refusal":null},"logprobs":null,"finish_reason":null}],"usage":null}

data: {"id":"chatcmpl-A8dyC7f6pKkQ516qqRHK6ep7Z3yG9","object":"chat.completion.chunk","created":1726623632,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_483d39d857","choices":[{"index":0,"delta":{"content":"Hello"},"logprobs":null,"finish_reason":null}],"usage":null}

data: {"id":"chatcmpl-A8dyC7f6pKkQ516qqRHK6ep7Z3yG9","object":"chat.completion.chunk","created":1726623632,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_483d39d857","choices":[{"index":0,"delta":{"content":" world"},"logprobs":null,"finish_reason":null}],"usage":null}

data: {"id":"chatcmpl-A8dyC7f6pKkQ516qqRHK6ep7Z3yG9","object":"chat.completion.chunk","created":1726623632,"model":"gpt-4o-2024-08-06","system_fingerprint":"fp_483d39d857","choices":[{"index":0,"delta":{},"logprobs":null,"finish_reason":"stop"}],"usage":null}

data: {"id":"chatcmpl-A8dyC7f6pKkQ516qqRHK6ep7Z3yG9","object":"chat.completion.chunk","created":1726623632,"model":"gpt-4o-2024-08-06","choices":[],"usage":{"prompt_tokens":24,"completion_tokens":12,"total_tokens":36}}

data: [DONE]
```

**Parsing rules for Swift:**
1. Strip the `data: ` prefix (6 characters) from each line
2. Check for the literal string `[DONE]` -- this signals end of stream
3. Parse the remaining string as JSON
4. Extract text from `choices[0].delta.content` (may be `null` or missing)
5. Check `choices[0].finish_reason` for `"stop"` to detect completion
6. The `object` type is always `"chat.completion.chunk"`

**Swift Codable structs:**
```swift
struct OpenAIStreamChunk: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIStreamChoice]
    let usage: OpenAIUsage?
}

struct OpenAIStreamChoice: Codable {
    let index: Int
    let delta: OpenAIDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

struct OpenAIDelta: Codable {
    let role: String?
    let content: String?
}

struct OpenAIUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
```

---

### 6.2 Anthropic Claude Streaming Format

**Request:** Add `"stream": true` to the normal messages JSON body.

**Content-Type returned:** `text/event-stream`

**Key difference from OpenAI:** Anthropic uses BOTH `event:` and `data:` lines per SSE event. OpenAI only uses `data:` lines.

**Raw SSE output (exactly as received over the wire):**

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_01ABC123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: ping
data: {"type":"ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":12}}

event: message_stop
data: {"type":"message_stop"}
```

**Parsing rules for Swift:**
1. Parse both `event:` and `data:` lines. The `event:` line tells you the event type.
2. For each `event: content_block_delta`, parse the `data:` JSON and extract `delta.text`
3. The event flow is: `message_start` -> N x (`content_block_start` -> N x `content_block_delta` -> `content_block_stop`) -> `message_delta` -> `message_stop`
4. `message_stop` signals end of stream (no `[DONE]` marker like OpenAI)
5. `ping` events should be ignored
6. Token usage comes in two places: `message_start` (input_tokens) and `message_delta` (output_tokens)

**Event types and what to do with each:**
| Event | Action |
|-------|--------|
| `message_start` | Store message ID, model, input token count |
| `content_block_start` | Initialize new content block at given index |
| `content_block_delta` | Append `delta.text` to accumulated response |
| `content_block_stop` | Finalize content block |
| `message_delta` | Read `stop_reason` and final `output_tokens` |
| `message_stop` | Close the stream, processing complete |
| `ping` | Ignore (keepalive) |

**Swift Codable structs:**
```swift
struct ClaudeStreamEvent: Codable {
    let type: String
}

struct ClaudeMessageStart: Codable {
    let type: String
    let message: ClaudeMessageInfo
}

struct ClaudeMessageInfo: Codable {
    let id: String
    let type: String
    let role: String
    let model: String
    let usage: ClaudeUsage
}

struct ClaudeContentBlockDelta: Codable {
    let type: String
    let index: Int
    let delta: ClaudeTextDelta
}

struct ClaudeTextDelta: Codable {
    let type: String
    let text: String
}

struct ClaudeMessageDelta: Codable {
    let type: String
    let delta: ClaudeStopDelta
    let usage: ClaudeUsage
}

struct ClaudeStopDelta: Codable {
    let stopReason: String?
    let stopSequence: String?

    enum CodingKeys: String, CodingKey {
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct ClaudeUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
```

---

### 6.3 Google Gemini Streaming Format

**Request:** Use the `streamGenerateContent` endpoint instead of `generateContent`, and append `?alt=sse` to the URL. The request body is identical to non-streaming.

**Streaming endpoint:**
```
POST https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:streamGenerateContent?alt=sse
```

**Content-Type returned:** `text/event-stream`

**Key difference from OpenAI/Anthropic:** Gemini only uses `data:` lines (no `event:` lines). Each chunk is a complete `GenerateContentResponse` object. There is no `[DONE]` marker -- the HTTP connection simply closes.

**Raw SSE output (exactly as received over the wire):**

```
data: {"candidates":[{"content":{"parts":[{"text":"Hello"}],"role":"model"},"finishReason":"STOP","index":0,"safetyRatings":[{"category":"HARM_CATEGORY_SEXUALLY_EXPLICIT","probability":"NEGLIGIBLE"},{"category":"HARM_CATEGORY_HATE_SPEECH","probability":"NEGLIGIBLE"},{"category":"HARM_CATEGORY_HARASSMENT","probability":"NEGLIGIBLE"},{"category":"HARM_CATEGORY_DANGEROUS_CONTENT","probability":"NEGLIGIBLE"}]}],"usageMetadata":{"promptTokenCount":6,"candidatesTokenCount":1,"totalTokenCount":7}}

data: {"candidates":[{"content":{"parts":[{"text":" world! How can I help you today?"}],"role":"model"},"finishReason":"STOP","index":0}],"usageMetadata":{"promptTokenCount":6,"candidatesTokenCount":12,"totalTokenCount":18}}

```

**Parsing rules for Swift:**
1. Strip the `data: ` prefix (6 characters) from each line
2. Parse the JSON as a `GenerateContentResponse`
3. Extract text from `candidates[0].content.parts[0].text`
4. Each chunk may include `usageMetadata` with cumulative token counts
5. The stream ends when the HTTP connection closes (no explicit terminator)
6. The `finishReason` field appears in every chunk (unlike OpenAI where it is only in the last one)
7. `safetyRatings` may appear in any/all chunks

**Swift Codable structs:**
```swift
struct GeminiStreamChunk: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let index: Int?
    let safetyRatings: [GeminiSafetyRating]?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

struct GeminiSafetyRating: Codable {
    let category: String
    let probability: String
}
```

---

### 6.4 Streaming Comparison Quick Reference

| Aspect | OpenAI | Anthropic Claude | Google Gemini |
|--------|--------|------------------|---------------|
| **Enable streaming** | `"stream": true` in body | `"stream": true` in body | Different endpoint + `?alt=sse` |
| **Streaming endpoint** | Same as non-streaming | Same as non-streaming | `:streamGenerateContent?alt=sse` |
| **SSE event: line** | No (data: only) | Yes (`event: message_start`, etc.) | No (data: only) |
| **Text location in chunk** | `choices[0].delta.content` | `delta.text` (in `content_block_delta`) | `candidates[0].content.parts[0].text` |
| **Stream terminator** | `data: [DONE]` | `event: message_stop` | HTTP connection close |
| **Usage in stream** | Final chunk (with `stream_options`) | Split: `message_start` + `message_delta` | Every chunk (cumulative) |
| **Finish signal** | `finish_reason: "stop"` | `stop_reason: "end_turn"` | `finishReason: "STOP"` |

---

### 6.5 Swift URLSession SSE Parsing Pattern

All three providers can be consumed with a single `URLSessionDataDelegate` pattern:

```swift
// Generic SSE line parser for URLSessionDataDelegate
class SSEParser {
    private var buffer = ""
    private var currentEvent = ""
    private var currentData = ""

    /// Call this from urlSession(_:dataTask:didReceive:)
    func feed(_ data: Data) -> [(event: String, data: String)] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        buffer += text

        var events: [(event: String, data: String)] = []

        // Split on double newline (event boundary)
        while let range = buffer.range(of: "\n\n") {
            let block = String(buffer[buffer.startIndex..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])

            var eventType = ""
            var eventData = ""

            for line in block.components(separatedBy: "\n") {
                if line.hasPrefix("event: ") {
                    eventType = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    let payload = String(line.dropFirst(6))
                    if !eventData.isEmpty { eventData += "\n" }
                    eventData += payload
                } else if line.hasPrefix(":") {
                    // Comment line, ignore
                    continue
                }
            }

            if !eventData.isEmpty {
                events.append((event: eventType, data: eventData))
            }
        }

        return events
    }
}
```

---

## Comparison Summary Table

| Feature | OpenAI GPT-4 | Anthropic Claude | Google Gemini | xAI Grok |
|---------|--------------|------------------|---------------|-----------|
| **Base Endpoint** | api.openai.com/v1 | api.anthropic.com/v1 | generativelanguage.googleapis.com | api.x.ai/v1 |
| **Auth Method** | Bearer token | x-api-key header | x-goog-api-key header | Bearer token |
| **Vision Support** | ✅ Full (images, PDFs) | ✅ Full (100 images/req) | ✅ Full (object detection, segmentation) | ✅ Via vision models |
| **Streaming** | ✅ SSE + Realtime API | ✅ SSE (<500ms TTFT) | ✅ SSE + WebSocket + Live API | ✅ SSE + Voice API + Verbose |
| **Computer Control** | 🚧 CUA (in dev) | ✅ Computer Use API | ✅ Live API agents | ✅ Agent Tools API |
| **Context Window** | Up to 1M tokens | Up to 1M tokens | Up to 128K-200K tokens | 2M tokens (all models) |
| **Cheapest Option** | GPT-4.1: $2/$8 | Haiku 4.5: $1/$5 | Flash-Lite: $0.075/$0.30 | Grok 4.1 Fast: $0.20/$0.50 |
| **Premium Option** | GPT-4.5 (preview) | Opus 4.5: $5/$25 | Gemini 3 Pro: $2/$12 | Grok 3/4: $3/$15 |
| **Batch Discount** | 50% off | 50% off | 50% off | N/A |
| **Caching** | 50-90% savings | Cache read: 0.1x price | Up to 75% savings | Cache read: ~$0.05/M |
| **Free Tier** | ❌ | ❌ | ✅ (5-15 RPM, 1K/day) | ❌ |
| **Unique Strengths** | CUA model, coding agents | Computer Use, long context | Multimodal foundation, Live API | Free agent tools, 2M context, X data |

---

## Recommendations for Computer Control

### Best Overall: Anthropic Claude
- **Why**: Production-ready Computer Use API, industry-leading performance
- **Best For**: GUI automation, screen interaction, enterprise workflows
- **Model**: Claude Opus 4.5 for maximum capability, Sonnet 4.5 for balance

### Best for Cost: Google Gemini
- **Why**: Free tier + lowest paid pricing, especially Flash-Lite models
- **Best For**: High-volume applications, prototyping, budget-conscious projects
- **Model**: Gemini 2.5 Flash-Lite for cost, Gemini 3 Pro for capability

### Best for Real-Time Voice: Google Gemini Live API
- **Why**: Enterprise-grade bidirectional streaming with multimodal input
- **Best For**: Voice agents, video understanding, live interactions
- **Model**: Gemini 2.5 Pro via Live API

### Best for Context: xAI Grok
- **Why**: 2M token context across all models, lowest context pricing
- **Best For**: Long document analysis, extended conversations, document-heavy workflows
- **Model**: Grok 4.1 Fast for cost + context

### Best for Agentic Workflows: xAI Grok (Free Tools) or OpenAI (Capability)
- **Why (Grok)**: Free Agent Tools API with autonomous tool calling, real-time data
- **Why (OpenAI)**: GPT-4.1 highest SWE-bench scores, dedicated CUA coming
- **Best For**: Autonomous agents, complex multi-step tasks
- **Model**: Grok 4 with Agent Tools, or GPT-4.1 with Responses API

### Coming Soon: OpenAI Computer-Using Agent (CUA)
- **Status**: In development, not yet in API
- **Potential**: Dedicated RL-trained model for GUI interaction
- **Watch**: Likely industry-leading once released in API

---

## Sources

### OpenAI GPT-4
- [Images and Vision | OpenAI API](https://platform.openai.com/docs/guides/images-vision)
- [Chat Completions | OpenAI API Reference](https://platform.openai.com/docs/api-reference/chat)
- [Models | OpenAI API](https://platform.openai.com/docs/models/)
- [GPT-4.1 Model | OpenAI API](https://platform.openai.com/docs/models/gpt-4.1)
- [GPT-5 Model | OpenAI API](https://platform.openai.com/docs/models/gpt-5)
- [Introducing GPT-5 | OpenAI](https://openai.com/index/introducing-gpt-5/)
- [Changelog | OpenAI API](https://platform.openai.com/docs/changelog)
- [OpenAI for Developers in 2025](https://developers.openai.com/blog/openai-for-developers-2025/)
- [Migrate to the Responses API | OpenAI](https://platform.openai.com/docs/guides/migrate-to-responses)
- [API Reference - OpenAI API](https://platform.openai.com/docs/api-reference/introduction)
- [Pricing | OpenAI](https://openai.com/api/pricing/)
- [Computer-Using Agent | OpenAI](https://openai.com/index/computer-using-agent/)

### Anthropic Claude
- [Vision - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/vision)
- [Messages Examples - Claude API](https://docs.anthropic.com/en/api/messages-examples)
- [Models Overview - Claude API Docs](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Using the Messages API - Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/working-with-messages)
- [API Overview - Claude API Docs](https://platform.claude.com/docs/en/api/overview)
- [Pricing - Claude API Docs](https://platform.claude.com/docs/en/about-claude/pricing)
- [Streaming Messages - Claude API Docs](https://docs.anthropic.com/en/api/messages-streaming)
- [Model Deprecations - Claude API Docs](https://platform.claude.com/docs/en/about-claude/model-deprecations)

### Google Gemini
- [Image Understanding | Gemini API](https://ai.google.dev/gemini-api/docs/image-understanding)
- [Gemini Models | Gemini API](https://ai.google.dev/gemini-api/docs/models)
- [Gemini API Reference | Google AI for Developers](https://ai.google.dev/api)
- [File Input Methods | Gemini API](https://ai.google.dev/gemini-api/docs/file-input-methods)
- [Gemini 3 Developer Guide | Gemini API](https://ai.google.dev/gemini-api/docs/gemini-3)
- [Introducing Gemini 3 Flash | Google Blog](https://blog.google/products/gemini/gemini-3-flash/)
- [GenerateContentResponse | Vertex AI](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/reference/rest/v1/GenerateContentResponse)
- [Gemini Developer API Pricing | Gemini API](https://ai.google.dev/gemini-api/docs/pricing)
- [Rate Limits | Gemini API](https://ai.google.dev/gemini-api/docs/rate-limits)

### xAI Grok
- [API | xAI](https://x.ai/api)
- [Models and Pricing | xAI](https://docs.x.ai/docs/models)
- [xAI API](https://docs.x.ai/docs/overview)
- [Grok Review 2026: We Tested xAI's Model](https://hackceleration.com/grok-review/)
- [Consumption and Rate Limits | xAI](https://docs.x.ai/docs/key-information/consumption-and-rate-limits)
- [Overview | xAI - Tools](https://docs.x.ai/docs/guides/tools/overview)
- [Grok 4.1 Fast and Agent Tools API | xAI](https://x.ai/news/grok-4-1-fast)
- [Grok Voice Agent API | xAI](https://x.ai/news/grok-voice-agent-api)

---

*Last Updated: January 31, 2026*
