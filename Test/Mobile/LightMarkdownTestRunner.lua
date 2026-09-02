local Content <const> = Dora.Content
local Path <const> = Dora.Path

local searchPaths = Content.searchPaths
searchPaths[#searchPaths + 1] = Path(Content.assetPath, "Script")
Content.searchPaths = searchPaths

package.loaded["Test.Mobile.LightMarkdownTest"] = nil
package.loaded["Dev.Mobile.LightMarkdown"] = nil
require("Test.Mobile.LightMarkdownTest")
