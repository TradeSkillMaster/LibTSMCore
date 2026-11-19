local Env = require("LibTSMCore.Tests.Env.Core")
Env.Init("LibTSMCore", "RETAIL")
Env.LoadAddonFiles({
	"LibTSMClass/LibTSMClass.lua",
	"LibTSMCore/LibTSMCore.xml",
})
Env.LoadTestCaseFiles({
	"LibTSMCore/Tests/ComponentTest.lua",
})
Env.Run()
