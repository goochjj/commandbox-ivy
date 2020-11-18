component {

	this.name      = "commandbox-ivy";
	this.cfmapping = "commandbox-ivy";

	function configure(){
		settings = { ivy_version : "2.5.0" };
	}

	function onLoad(){
		var bundleService = wirebox.getInstance( "BundleService@commandbox-ivy" );
		var jarFile       = modulePath & "/lib/ivy/ivy-#settings.ivy_version#.jar";

		if (
			!bundleService.isBundleInstalled(
				"org.apache.ivy",
				settings.ivy_version
			)
		) {
			bundleService.installBundle( jarFile );
		}
	}

}
