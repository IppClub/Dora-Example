local Content <const> = Dora.Content
local Path <const> = Dora.Path

local searchPaths = Content.searchPaths
searchPaths[#searchPaths + 1] = Content.assetPath
searchPaths[#searchPaths + 1] = Path(Content.assetPath, "Script")
Content.searchPaths = searchPaths

package.loaded["Test.Mobile.MobileCatalogIntegrationTest"] = nil
package.loaded["Dev.Mobile.MobileCatalog"] = nil
package.loaded["Script.Tools.ResourceDownloader.CatalogSync"] = nil
require("Test.Mobile.MobileCatalogIntegrationTest")
