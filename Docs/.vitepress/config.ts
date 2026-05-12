import { defineConfig } from "vitepress"

export default defineConfig({
	base: "/LibTSMCore/",
	title: "LibTSMCore",
	ignoreDeadLinks: true,
	description: "Component and module framework for World of Warcraft addons",
	themeConfig: {
		nav: [
			{ text: "Home", link: "/" },
		],
		sidebar: [
			{
				items: [
					{ text: "Home", link: "/" },
					{ text: "Features", link: "/features" },
					{
						text: "API",
						items: [
							{ text: "LibTSMCore", link: "/LibTSMCore" },
							{ text: "LibTSMComponent", link: "/LibTSMComponent" },
							{ text: "LibTSMModule", link: "/LibTSMModule" },
						],
					},
				],
			},
		],
	},
})
