local Content <const> = Dora.Content
local Path <const> = Dora.Path

local searchPaths = Content.searchPaths
searchPaths[#searchPaths + 1] = Path(Content.assetPath, "Script")
Content.searchPaths = searchPaths

package.loaded["Test.Mobile.LifecycleTest"] = nil
package.loaded["Dev.Mobile.Lifecycle"] = nil
require("Test.Mobile.LifecycleTest")
