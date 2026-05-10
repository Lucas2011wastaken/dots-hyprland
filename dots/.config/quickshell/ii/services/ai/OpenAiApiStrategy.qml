import QtQuick

ApiStrategy {
    property bool isReasoning: false
    // Buffer for accumulating streamed tool call arguments (DeepSeek may send them in chunks)
    property var bufferedToolCalls: ({})
    
    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    const hasFunctionCall = message.functionCall !== undefined && message.functionName?.length > 0;
                    let msg = {
                        "role": message.role,
                        "content": message.rawContent,
                    };
                    // DeepSeek requires reasoning_content to be passed back in multi-turn conversations
                    if (message.role === "assistant" && message.reasoningContent?.length > 0) {
                        msg.reasoning_content = message.reasoningContent;
                    }
                    // Handle tool call messages for multi-turn conversations
                    if (hasFunctionCall) {
                        if (message.functionResponse?.length > 0) {
                            // This is a tool response message
                            msg.role = "tool";
                            msg.content = message.functionResponse;
                            msg.tool_call_id = message.functionCall.id;
                        } else {
                            // This is the assistant message that invoked the tool
                            msg.content = message.content;
                            msg.tool_calls = [{
                                id: message.functionCall.id,
                                type: "function",
                                function: {
                                    name: message.functionName,
                                    arguments: JSON.stringify(message.functionCall.args ?? {})
                                }
                            }];
                        }
                    }
                    return msg;
                }),
            ],
            "stream": true,
            "tools": tools,
            "temperature": temperature,
        };
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // console.log("[AI] OpenAI: Data:", cleanData);
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            // If we have buffered tool calls, trigger the function call now
            if (bufferedToolCalls.name && bufferedToolCalls.arguments) {
                return flushBufferedToolCall(message);
            }
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            // --- Tool calls (function calling) handling ---
            // DeepSeek streams tool calls in chunks, so we need to accumulate arguments
            const deltaToolCalls = dataJson.choices[0]?.delta?.tool_calls;
            if (deltaToolCalls && deltaToolCalls.length > 0) {
                const tc = deltaToolCalls[0];
                if (tc.id) bufferedToolCalls.id = tc.id;
                if (tc.type) bufferedToolCalls.type = tc.type;
                if (tc.function) {
                    if (tc.function.name) bufferedToolCalls.name = tc.function.name;
                    if (tc.function.arguments !== undefined) {
                        bufferedToolCalls.arguments = (bufferedToolCalls.arguments || "") + tc.function.arguments;
                    }
                }
                // If finish_reason is tool_calls in this chunk, flush immediately
                if (dataJson.choices[0]?.finish_reason === "tool_calls") {
                    return flushBufferedToolCall(message);
                }
                return {};
            }

            // Check for finish_reason indicating tool calls (some providers send it separately)
            if (dataJson.choices[0]?.finish_reason === "tool_calls") {
                if (bufferedToolCalls.name && bufferedToolCalls.arguments) {
                    return flushBufferedToolCall(message);
                }
            }

            let newContent = "";

            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.choices[0]?.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content
                || dataJson.choices[0]?.message?.reasoning || dataJson.choices[0]?.message?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
                // Save raw reasoning_content for multi-turn compatibility (DeepSeek)
                message.reasoningContent = (message.reasoningContent || "") + responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                // If we have buffered tool calls, trigger the function call now
                if (bufferedToolCalls.name && bufferedToolCalls.arguments) {
                    return flushBufferedToolCall(message);
                }
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }

    function flushBufferedToolCall(message) {
        let functionArgs = {};
        try {
            functionArgs = JSON.parse(bufferedToolCalls.arguments) || {};
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse tool call arguments: ", e);
        }
        const functionName = bufferedToolCalls.name;
        const functionId = bufferedToolCalls.id || ("call_" + Date.now().toString(36));
        const newContent = `\n\n[[ Function: ${functionName}(${JSON.stringify(functionArgs, null, 2)}) ]]\n`;
        message.rawContent += newContent;
        message.content += newContent;
        message.functionName = functionName;
        message.functionCall = functionName;
        // Reset buffer
        bufferedToolCalls = ({});
        return { functionCall: { name: functionName, args: functionArgs, id: functionId } };
    }
    
    function onRequestFinished(message) {
        // OpenAI format doesn't need special finish handling
        return {};
    }
    
    function reset() {
        isReasoning = false;
        bufferedToolCalls = ({});
    }

}
