
> I’m thrilled to have put together some scripts (all in .\prop) using AI. My sincere thanks go out to those pushing the boundaries of science, and of course, to the "machines" themselves. 
> 
> Most of the README's text was translated by [gemini-3-flash-preview](https://blog.google/products/gemini/gemini-3-flash/ "blog.google"). 

## "playlist" 

|  🤖Scripts  |  🤗AI-coders  |
|  ----  |  ----  |
| `edl2srt_KIMIK2.bat`  | [moonshotai/Kimi-K2-Thinking](https://huggingface.co/moonshotai/Kimi-K2-Thinking "HF") |
| `edl2srt_GLM47.ps1` | [zai-org/GLM-4.7](https://huggingface.co/zai-org/GLM-4.7 "HF") |

___

## Some Usage Instructions 

### `edl2srt_GLM47.ps1`

- power shell `".\edl2srt.ps1" "input.edl" "output.srt" -Fps 23.976` 
- The default encoding is set to `Windows 1252` (EDL exported from Premiere Pro). 
  - Force-decode as UTF-8 encoding `".\edl2srt.ps1" "input.edl" "output.srt" -Encoding UTF8 -Fps 23.976` 
- Support for fractional frame rates. 
