component
output="false"
{	
	public any function init()
	output="false"
	{
		this.version = "0.9.3,1.0,1.1,1.1.8";
		return this;
	}
	
	/**
	 * @hint "Shortcut method to 'localize'"
	 * 
	 * @text "Text to localize"
	 */
	public any function l(required string text)
	output="false"
	{
		return localize(arguments.text);
	}

	/**
	 * @hint "Search for 'text' in the repository and return the transalation for the current locale"
	 *
	 * If the environment is design or development and no translation is found add 'text' to the rpository and return it.
	 *
	 * @text "Text to localize"
	 */
	public any function localize(required string text)
	output="false"
	{
		var loc = {};
		
		arguments.source = $captureTemplateAndLineNumber();
		
		loc.result = "";
		loc.textContainsDynamicText = (arguments.text CONTAINS "{" AND arguments.text CONTAINS "}");
		// get the text from the repo for the local specified
		loc.localizedText = $getLocalizedText();
		
		if (loc.textContainsDynamicText)
		{
			loc.textBetweenDynamicText = REMatch("{(.*?)}", arguments.text);
			loc.iEnd = ArrayLen(loc.textBetweenDynamicText);
			for (loc.i = 1; loc.i lte loc.iEnd; loc.i++)
				arguments.text = Replace(arguments.text, loc.textBetweenDynamicText[loc.i], "{variable}", "all");
		}
		// Return the localized text in the current locale
		loc.translation = $findLocalizedText(text=arguments.text, struct=loc.localizedText, source=arguments.source);
		if (ListFindNoCase("design,development", get("environment")))
		{
			if (Len(loc.translation))
			{
				loc.result = loc.translation;
			}
			else
			{
				$writeTextIntoLocalizationRepository(text=arguments.text, source=arguments.source);
				loc.result = arguments.text;
			}
		}
		else if (Len(loc.translation))
		{
			loc.result = loc.translation;
		}
		if (loc.textContainsDynamicText)
		{
			// Go through the array and replace the "{variable}" back with the respective values 
			loc.iEnd = ArrayLen(loc.textBetweenDynamicText);
			for (loc.i = 1; loc.i lte loc.iEnd; loc.i++)
				loc.result = Replace(loc.result, "{variable}", loc.textBetweenDynamicText[loc.i]);
			// Remove all "{}"
			loc.result = ReplaceList(loc.result, "{,}", "");
		}
		return loc.result;
	}

	/**
	 * @hint "Since ColdFusion has several names for locales and not the standard 5 letters code, this function will enforce the return of the locale in the 5 letter code"
	 */
	public string function getLocaleCode()
	{
		var loc = {};
		loc.currentLocale = getLocale();
		// translate coldfusion locales to their corresponding codes
		if (Len(loc.currentLocale) gt 5)
		{
			switch (loc.currentLocale)
			{
				case "Chinese (China)":        { loc.currentLocale = "zh_CN"; break; }
				case "Chinese (Hong Kong)":    { loc.currentLocale = "zh_HK"; break; }
				case "Chinese (Taiwan)":       { loc.currentLocale = "zh_TW"; break; }
				case "Dutch (Belgian)":        { loc.currentLocale = "nl_BE"; break; }
				case "Dutch (Standard)":       { loc.currentLocale = "nl_NL"; break; }
				case "English (Australian)":   { loc.currentLocale = "en_AU"; break; }
				case "English (Canadian)":     { loc.currentLocale = "en_CA"; break; }
				case "English (New Zealand)":  { loc.currentLocale = "en_NZ"; break; }
				case "English (UK)":           { loc.currentLocale = "en_GB"; break; }
				case "English (US)":           { loc.currentLocale = "en_US"; break; }
				case "French (Belgian)":       { loc.currentLocale = "fr_BE"; break; }
				case "French (Canadian)":      { loc.currentLocale = "fr_CA"; break; }
				case "French (Standard)":      { loc.currentLocale = "fr_FR"; break; }
				case "French (Swiss)":         { loc.currentLocale = "fr_CH"; break; }
				case "German (Austrian)":      { loc.currentLocale = "de_AT"; break; }
				case "German (Standard)":      { loc.currentLocale = "de_DE"; break; }
				case "German (Swiss)":         { loc.currentLocale = "de_CH"; break; }
				case "Italian (Standard)":     { loc.currentLocale = "it_IT"; break; }
				case "Italian (Swiss)":        { loc.currentLocale = "it_CH"; break; }
				case "Japanese":               { loc.currentLocale = "ja_JP"; break; }
				case "Korean":                 { loc.currentLocale = "ko_KR"; break; }
				case "Norwegian (Bokmal)":     { loc.currentLocale = "no_NO"; break; }
				case "Norwegian (Nynorsk)":    { loc.currentLocale = "no_NO"; break; }
				case "Portuguese (Brazilian)": { loc.currentLocale = "pt_BR"; break; }
				case "Portuguese (Standard)":  { loc.currentLocale = "pt_PT"; break; }
				case "Spanish (Mexican)":      { loc.currentLocale = "es_MX"; break; }
				case "Spanish (Modern)":       { loc.currentLocale = "es_US"; break; }
				case "Spanish (Standard)":     { loc.currentLocale = "es_ES"; break; }
				case "Swedish":                { loc.currentLocale = "sv_SE"; break; }
			}
		}
		return loc.currentLocale;
	}
	
	/**
	 * @hint "Search for translatable strings in folderList and add them to the repository"
	 *
	 * May only be run in design or development modes.
	 *
	 * @folderList "List of folders to search for translations"
	 */
	public void function $$populateRepository(string folderList="controllers,models,views")
	output="false"
	{
		var loc = {};
		
		if (!ListFindNoCase("design,development", get("environment")))
			$throw(type="Wheels.Localizer.AccessDenied", message="The method `$$populateRepository` may only be run in design or development modes.");
		
		//writeOutput("Folders to work on: #arguments.folderList#");
		//writeOutput("<ul>");
		loc.iEnd = ListLen(arguments.folderList);
		for (loc.i = 1; loc.i lte loc.iEnd; loc.i++)
		{
			// get our directory from the list
			loc.relativeDir = ListGetAt(arguments.folderList, loc.i);
			
			// decide how we should filter the files
			if (ListFindNoCase("controllers,models", loc.relativeDir))
				loc.filter = "*.cfc";
			else
				loc.filter = "*.cfm";
			
			loc.files = $directory(action="list", type="file", recurse=true, filter=loc.filter, listInfo="name", directory=ExpandPath(loc.relativeDir));
			//writeOutput("<li>#loc.relativeDir#</li>");
			//writeOutput("<ul>");
			loc.xEnd = loc.files.RecordCount;
			for (loc.x = 1; loc.x lte loc.xEnd; loc.x++)
			{
				loc.file = loc.relativeDir & "/" & loc.files.name[loc.x];
				loc.fileReader = CreateObject("java", "java.io.FileReader").init(ExpandPath(loc.file));
				loc.lineReader = CreateObject("java","java.io.LineNumberReader").init(loc.fileReader);
				
				loc.line = loc.lineReader.readLine();  
				loc.lineCount = 1;  
				//writeOutput("<li>#loc.files.name[loc.x]#</li>");
				while (StructKeyExists(loc, "line")) 
				{
					loc.matches = REMatch("([^a-zA-Z0-9]l|[^a-zA-Z0-9]localize)[[:space:]]?(\([[:space:]]?['""](.*?)['""][[:space:]]?)\)", loc.line);
					loc.mEnd = ArrayLen(loc.matches);
					for (loc.m = 1; loc.m lte loc.mEnd; loc.m++)
					{
						// for each match we have for the line, write it to the repo
						loc.matches[loc.m] = REReplace(loc.matches[loc.m], 
								"([^a-zA-Z0-9]l|[^a-zA-Z0-9]localize)[[:space:]]?(\([[:space:]]?['""])", "", "all");
						loc.matches[loc.m] = REReplace(loc.matches[loc.m], "(['""][[:space:]]?)\)", "", "all");
						
						loc.textContainsDynamicText = (loc.matches[loc.m] CONTAINS "{" AND loc.matches[loc.m] CONTAINS "}");
						if (loc.textContainsDynamicText)
						{
							loc.textBetweenDynamicText = REMatch("{(.*?)}", loc.matches[loc.m]);
							loc.nEnd = ArrayLen(loc.textBetweenDynamicText);
							for (loc.n = 1; loc.n lte loc.nEnd; loc.n++)
								loc.matches[loc.m] = Replace(loc.matches[loc.m], loc.textBetweenDynamicText[loc.n], "{variable}", "all");
						}
						
						loc.source = {};
						loc.source.template = loc.file;
						loc.source.line = loc.lineCount;
						$writeTextIntoLocalizationRepository(text=loc.matches[loc.m], source=loc.source);
					}
					// do something here with the data in variable line
					loc.line = loc.lineReader.readLine();
					loc.lineCount++;
				}
			}
			//writeOutput("</ul>");
		}
		//writeOutput("</ul>");
	}
	
	/**
	 * @hint "Find a translation for 'text' in 'struct'"
	 *
	 * @text "The text to translate"
	 * @struct "The struct containing the translation repository"
	 * @source "Struct containing the template name and line of the translation in the sourcecode"
	 */
	public string function $findLocalizedText(required string text, required struct struct, required struct source)
	output="false"
	{
		var loc = {};
		loc.hash = Hash(arguments.text,'SHA-1','utf-8');
		loc.returnValue = "";
		if (StructKeyExists(arguments.struct, loc.hash))
			loc.returnValue = arguments.struct[loc.hash];
		return loc.returnValue;
	}

	/**
	 * @hint "Load the struct containing the translations"
	 *
	 * @fromRepository "Determines whether to load the translation (en.cfm, de.cfm) or the untranslated repository (repository.cfm)"
	 */
	public struct function $getLocalizedText(boolean fromRepository=false)
	output="false"
	{
		var loc = {};
		loc.texts = {}; // initialize this value in case we write a file
		
		if (!arguments.fromRepository)
			loc.currentLocale = getLocaleCode();
		else
			loc.currentLocale = "repository";
		
		loc.includePath = LCase("locales/#loc.currentLocale#.cfm");
		loc.filePath = LCase("plugins/localizer/locales/#loc.currentLocale#.cfm");
		if (FileExists(ExpandPath(loc.filePath)))
			loc.texts = $includeRepository(loc.includePath);
		else
			$file(action="write", file=ExpandPath(loc.filePath), output="");
		return loc.texts;
	}
	
	/**
	 * @hint "Writes the text to the localization repository"
	 * 
	 * @text "Text to write"
	 * @source "Source of the text to write"
	 */
	public void function $writeTextIntoLocalizationRepository(required string text, required struct source)
	output="false"
	{
		var loc = {};
		loc.CRLF = Chr(13) & Chr(10);
		loc.hash = Hash(arguments.text,'SHA-1','utf-8');
		
		savecontent variable="loc.text" {
			WriteOutput('[!--- (source: #source.template#:#source.line#) "#arguments.text#" ---]' & loc.CRLF);
			WriteOutput('[cfset loc["#loc.hash#"] = "#arguments.text#"]]');
		}
		if (!StructKeyExists(request, "localizer") or !StructKeyExists(request.localizer, "writes"))
			request.localizer.writes = {};		
		loc.repo = $getLocalizedText(fromRepository=true);
		// Check first if the variable is written already
		loc.repoString = $findLocalizedText(text=arguments.text, struct=loc.repo, source=arguments.source);
		loc.inRequest = $findLocalizedText(text=arguments.text, struct=request.localizer.writes, source=arguments.source);
		if (!Len(loc.repoString) && !Len(loc.inRequest))
		{
			// transform file output
			loc.text = ReplaceList(loc.text, "[!---,---]", "<!---,--->");
			loc.text = ReplaceList(loc.text, "[cfset,]]", "<cfset, />");
			$file(action="append", file=ExpandPath("plugins/localizer/locales/repository.cfm"), output=loc.text);
			// when we have template caching turned on in coldfusion, the first version of the template is the one that will be 
			// retrieved for the rest of the request, not good
			request.localizer.writes[loc.hash] = arguments.text;
		}
	}
	
	/**
	 * @hint "Captures name and line number from calling template"
	 */
	public struct function $captureTemplateAndLineNumber()
	output="false"
	{
			var loc = {};
			
			loc.ret = $getCallingTemplateInfo();
			// change template name from full to relative path
			// instead of RemoveChars, lets replace the path since replace will cause less issues
			loc.ret.template = ListChangeDelims(
					ReplaceNoCase(loc.ret.template, ExpandPath(application.wheels.webpath), ""), "/", "\/"); 
		return loc.ret;
	}
	
	/**
	 * @hint "Captures name and line number from calling template"
	 */
	public struct function $getCallingTemplateInfo()
	output="false"
	{
		var loc = {};
		loc.returnValue = { template = "unknown", line = "unknown"};
		loc.stackTrace = CreateObject("java", "java.lang.Throwable").getStackTrace();
		
		loc.iEnd = ArrayLen(loc.stackTrace);
		for (loc.i = 1; loc.i lte loc.iEnd; loc.i++)
		{
			loc.fileName = loc.stackTrace[loc.i].getFileName();
			if (StructKeyExists(loc, "fileName") && !FindNoCase(".java", loc.fileName) 
					&& !FindNoCase("Localizer.cfc", loc.fileName) && !FindNoCase("<generated>", loc.fileName))
			{
				loc.returnValue.template = loc.fileName;
				loc.returnValue.line = loc.stackTrace[loc.i].getLineNumber();
				break;
			}
		}
		return loc.returnValue;
	}
	
	/**
	 * @hint "Includes the struct containing the translations if it is not already cached in this request"
	 *
	 * @template "Path to the repository to include"
	 */
	public struct function $includeRepository(required string template)
	output="false"
	{
		var loc = {};
		if(!StructKeyExists(request, "localizer") || !StructKeyExists(request.localizer, "cache"))
			request.localizer.cache = {};
		
		if(StructKeyExists(request.localizer.cache, arguments.template))
			return request.localizer.cache[arguments.template];
		
		include "#arguments.template#";
		request.localizer.cache[arguments.template] = Duplicate(loc);
		return loc;
	}
	
	/**
	 * @fromTime "Date to compare from."
	 * @toTime "Date to compare to."
	 * @includeSeconds "Whether or not to include the number of seconds in the returned string."
	 */
	public string function distanceOfTimeInWords(required string fromTime, required string toTime, boolean includeSeconds=false)
	output="false"
	{
		var loc = {};
		$args(name="distanceOfTimeInWords", args=arguments);
		loc.minuteDiff = DateDiff("n", arguments.fromTime, arguments.toTime);
		loc.secondDiff = DateDiff("s", arguments.fromTime, arguments.toTime);
		loc.hours = 0;
		loc.days = 0;
		loc.returnValue = "";
		if (loc.minuteDiff <= 1)
		{
			if (loc.secondDiff < 60)
				loc.returnValue = l("less than a minute");
			else
				loc.returnValue = l("1 minute");
			if (arguments.includeSeconds)
			{
				if (loc.secondDiff < 5)
					loc.returnValue = l("less than 5 seconds");
				else if (loc.secondDiff < 10)
					loc.returnValue = l("less than 10 seconds");
				else if (loc.secondDiff < 20)
					loc.returnValue = l("less than 20 seconds");
				else if (loc.secondDiff < 40)
					loc.returnValue = l("half a minute");
			}
		}
		else if (loc.minuteDiff < 45)
		{
			loc.returnValue = l("{#loc.minuteDiff#} minutes");
		}
		else if (loc.minuteDiff < 90)
		{
			loc.returnValue = l("about 1 hour");
		}
		else if (loc.minuteDiff < 1440)
		{
			loc.hours = Ceiling(loc.minuteDiff/60);
			loc.returnValue = l("about {#loc.hours#} hours");
		}
		else if (loc.minuteDiff < 2880)
		{
			loc.returnValue = l("1 day");
		}
		else if (loc.minuteDiff < 43200)
		{
			loc.days = Int(loc.minuteDiff/1440);
			loc.returnValue = l("{#loc.days#} days");
		}
		else if (loc.minuteDiff < 86400)
		{
			loc.returnValue = l("about 1 month");
		}
		else if (loc.minuteDiff < 525600)
		{
			loc.months = Int(loc.minuteDiff/43200);
			loc.returnValue = l("{#loc.months#} months");
		}
		else if (loc.minuteDiff < 657000)
		{
			loc.returnValue = l("about 1 year");
		}
		else if (loc.minuteDiff < 919800)
		{
			loc.returnValue = l("over 1 year");
		}
		else if (loc.minuteDiff < 1051200)
		{
			loc.returnValue = l("almost 2 years");
		}
		else if (loc.minuteDiff >= 1051200)
		{
			loc.years = Int(loc.minuteDiff/525600);
			loc.returnValue = l("over {#loc.years#} years");
		}
		return loc.returnValue;
	}
}
