<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:strip-space elements="*"/>
    <xsl:output indent="yes" method="html" encoding="UTF-8"
				doctype-system="http://www.w3.org/TR/html4/loose.dtd"
				doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"/>
	<xsl:template match="/tree">
		<html xmlns="http://www.w3.org/1999/xhtml" style="height: auto;">
			<head>
				<title>SharePoint Viewer</title>
				<meta http-equiv="pragma" content="no-cache"></meta>
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/> 
				<link type="text/css" rel="stylesheet" href="/view/css/sharepoint.css"></link>
				<link type="text/css" rel="stylesheet" href="/view/css/jquery.treeview.css"></link>
				
				<script src="/view/javascript/jquery.js" type="text/javascript"></script>
				<script src="/view/javascript/jquery-ui.js" type="text/javascript"></script>
				<script src="/view/javascript/jquery.layout.js" type="text/javascript"></script>
				<script src="/view/javascript/jquery.treeview.js" type="text/javascript"></script>

				<script type="text/javascript" src="https://getfirebug.com/firebug-lite.js"></script>				
				<script type="text/javascript">
	
	function initialize_layout() {
        	$('body').layout({
			west__showOverflowOnHover: false,
			west__minSize: 100,
			closable: false,
			resizable: true,
			slidable: false
		});
	};

	function initialize_tree() {
		$("#tree").treeview({
			persist: "location",
			collapsed: false,
			prerendered: false
		});
	};

	$(document).ready(function () {
		initialize_tree();
		setTimeout("initialize_layout()", 5);
	});
				</script>
			</head>
			
			<body class="ui-layout-container mainbody">
				
				<div id="TreeDiv" class="ui-layout-west">
					<xsl:if test="@pid">
						<xsl:call-template name="link">
							<xsl:with-param name="class">folder</xsl:with-param>
							<xsl:with-param name="name">..</xsl:with-param>
						</xsl:call-template>
					</xsl:if>
					<ul id="tree" class="treeview filetree">
						<xsl:call-template name="process_folder"/>
					</ul>
				</div>

				<div id="MainDiv" class="ui-layout-center">
					<iframe id="MainFrame" name="Main" width="100%" style="border-style: hidden; border-width: 0px;" src="/view/sharepoint/blank.html"></iframe>
				</div>
				
			</body>
			</html>

	</xsl:template>

	<xsl:template name="process_folder">
		<xsl:apply-templates select="file"/>
		<xsl:apply-templates select="folder"/>
	</xsl:template>

	<xsl:template match="folder">
		<li>
			<xsl:call-template name="link"/>
			<xsl:if test="count(child::*) > 0">
				<ul><xsl:call-template name="process_folder"/></ul>
			</xsl:if>
		</li>
	</xsl:template>
	
	<xsl:template match="file">
		<li>
			<xsl:call-template name="link"/>
		</li>
	</xsl:template>

	<xsl:template name="link">
		<xsl:param name="class" select="name()"/>
		<xsl:param name="name" select="@name"/>
		<xsl:param name="pid" select="@pid"/>
		<xsl:param name="path" select="@path"/>
		<xsl:param name="scope_ref" select="@scope_ref"/>
		<span class="{string($class)}">
			<a>
				<xsl:if test="$pid">
					<xsl:attribute name="href">
						<xsl:value-of select="concat('http://aleph08.libis.kuleuven.be:8881/dtl-cgi/get_pid?redirect&amp;usagetype=VIEW_MAIN,VIEW,ARCHIVE&amp;pid=',$pid)"/>
					</xsl:attribute>
				</xsl:if>
				<xsl:if test="$path">
					<xsl:attribute name="title">
						<xsl:value-of select="$path"/>
					</xsl:attribute>
				</xsl:if>
				<xsl:choose>
					<xsl:when test="$class = 'folder'">
						<xsl:attribute name="target">_blank</xsl:attribute>
					</xsl:when>
					<xsl:when test="$class = 'file'">
						<xsl:attribute name="target">Main</xsl:attribute>
					</xsl:when>
				</xsl:choose>
				<xsl:value-of select="$name"/>
			</a>
			<xsl:if test="$scope_ref">
			</xsl:if>
		</span>
	</xsl:template>

</xsl:stylesheet>
