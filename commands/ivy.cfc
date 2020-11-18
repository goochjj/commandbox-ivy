/**
 * Use ivy.xml to download java dependencies
 * {code:bash}
 * ivy
 * {code}
 * .
 * Generate html report instead of console output.
 * .
 * {code:bash}
 * ivy reportDir=./reports/
 * {code}
 */
component {

	// What ivy version we are using.
	variables.IVY_VERSION  = "2.5.0";

	/*
	 * Constructor
	 */
	function init(){
		variables.rootPath = reReplaceNoCase(
			getDirectoryFromPath( getCurrentTemplatePath() ),
			"commands(\\|/)",
			""
		);
		variables.ivyJAR = rootPath & "lib/ivy/ivy-#variables.IVY_VERSION#.jar";

		return this;
	}

	/**
	* Run ivy dependency task
	*
	* @path path to ivy.xml
	* @libDir directory path to place resolved dependency jars in
	* @baseDir base directory for Ivy
	* @cacheDir cache directory for Ivy
	* @reportDir if specified, place a resolution report in this directory
	*/
	public function run(
		path="./ivy.xml",
		libDir="./lib/",
		baseDir=".",
		cacheDir="./cache",
		reportDir=""
	)  {
		arguments.path = fileSystemUtil.resolvePath(arguments.path);
		if (!fileExists(arguments.path)) {
			error("Path File does not exist: #arguments.path#");
		}
		arguments.libDir = fileSystemUtil.resolvePath(arguments.libDir);
		arguments.baseDir = fileSystemUtil.resolvePath(arguments.baseDir);
		arguments.cacheDir = fileSystemUtil.resolvePath(arguments.cacheDir);

 		var ivySettings = javaobj( "org.apache.ivy.core.settings.IvySettings" ).init();
		// Now let's set the basedir of the ivy settings to some location
		ivySettings.setBaseDir( javaobj( "java.io.File" ).init( baseDir ) );
		ivySettings.setDefaultCache( javaobj( "java.io.File" ).init( cacheDir ) );

		// create an ivy instance
		var ivy = javaobj( "org.apache.ivy.Ivy" ).newInstance(ivySettings);
		ivy.configureDefault();

		var resolveOptions = javaobj( "org.apache.ivy.core.resolve.ResolveOptions" ).init();
		resolveOptions.setConfs( javacast( "java.lang.String[]", [ "*" ] ) );
		resolveOptions.setUseCacheOnly( javacast( "boolean", false ) );
		resolveOptions.setLog( javaobj( "org.apache.ivy.core.LogOptions" ).LOG_DEFAULT );

		var resolveReport = ivy.resolve( javaobj( "java.io.File" ).init(basedir&"/ivy.xml"), resolveOptions );
		if (resolveReport.hasError())
		{
			var problems = resolveReport.getAllProblemMessages();
			if (!isNull(problems)) {
				for( problem in problems ) {
					error(problem);
				}
				return 1;
			}
		} else {
			print.yellowLine("Dependencies were successfully resolved");
		}

		// Now that the dependencies have been resolved, let now retrieve them
		// Get the descriptor
		var md = resolveReport.getModuleDescriptor();
		// module revision id of the module whose dependencies were resolved
		var mrid = md.getModuleRevisionId();

		// options that we pass to ivy instance for retrieve the dependencies
		var retrieveOptions = javaobj( "org.apache.ivy.core.retrieve.RetrieveOptions" ).init();

		// the Ivy pattern which will be used for retrieving the dependencies
		var pattern = libDir&"/[artifact]-[revision].[ext]";
		retrieveOptions.setDestArtifactPattern(pattern);

		// default logging option
		retrieveOptions.setLog( javaobj( "org.apache.ivy.core.LogOptions" ).LOG_DEFAULT );
		retrieveOptions.setConfs( javacast( "java.lang.String[]", [ "runtime" ] ) );
		retrieveOptions.setSync( javacast( "boolean", true ) );
		retrieveOptions.setMakeSymlinks( javacast( "boolean", false ) );

		// retrieve them!
		var packagesRetrieved = ivy.retrieve(mRID, pattern, retrieveOptions);

		print.yellowLine("Retrieved " & packagesRetrieved & " dependencies");

		if ( len(reportDir) ) {
			arguments.reportDir = fileSystemUtil.resolvePath(arguments.reportDir);
			if ( !DirectoryExists(reportDir) ) {
				directoryCreate(reportDir);
			}
			var cacheMgr = ivy.getResolutionCacheManager();
			var css = cacheMgr.getResolutionCacheRoot() & "/ivy-report.css";
			if (!fileExists(css)) {
				var fos = javaobj( "java.io.FileOutputStream" ).init(css);

				javaobj("org.apache.commons.io.IOUtils").copy(
					javaobj("org.apache.ivy.plugins.report.XmlReportOutputter").getClass().getResourceAsStream("ivy-report.css"),
					fos
				);
				fos.close();
			}
			var style = cacheMgr.getResolutionCacheRoot() & "/ivy-report.xsl";
			if (!fileExists(style)) {
				var fos = javaobj( "java.io.FileOutputStream" ).init(style);

				javaobj("org.apache.commons.io.IOUtils").copy(
					javaobj("org.apache.ivy.plugins.report.XmlReportOutputter").getClass().getResourceAsStream("ivy-report.xsl"),
					fos
				);
				fos.close();
			}
			fileCopy( css, reportDir&"/ivy-report.css" );
			var rptXml = fileRead( cacheMgr.getConfigurationResolveReportInCache(resolveReport.getResolveId(), "runtime").toString() );
			var rptXsl = fileRead( style );
			rptXml = XmlTransform( rptXml, rptXsl );
			fileWrite( reportDir&"/report.html", rptXml );
			print.yellowLine( "Report written to "&reportDir&"/report.html" );

		}
	}

	/**
	 * Runs Ivy using the Java API
	 */
	private any function javaobj( required string objName ){
		try {
			return createObject(
				"java",
				objName,
				"org.apache.ivy"
			);
		} catch ( any e ) {
			getInstance( "BundleService@commandbox-ivy" ).installBundle( ivyJAR );
			return createObject(
				"java",
				objName,
				"org.apache.ivy"
			);
		}
	}


}
