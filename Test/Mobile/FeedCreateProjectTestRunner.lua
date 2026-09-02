local Content <const> = Dora.Content
local Director <const> = Dora.Director
local Path <const> = Dora.Path

local searchPaths = Content.searchPaths
searchPaths[#searchPaths + 1] = Path(Content.assetPath, "Script")
Content.searchPaths = searchPaths

Director:clearSystemUI()
package.loaded["Test.Mobile.FeedCreateProjectTest"] = nil
package.loaded["Dev.Mobile.Feed"] = nil
require("Test.Mobile.FeedCreateProjectTest")
