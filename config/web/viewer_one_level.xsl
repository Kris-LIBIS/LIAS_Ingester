<?xml version="1.0" encoding="windows-1252"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:strip-space elements="*"/>
    <xsl:output indent="yes" method="html" encoding="UTF-8"
				doctype-system="http://www.w3.org/TR/html4/loose.dtd"
				doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"/>
	<xsl:template match="/tree">
		<html xmlns="http://www.w3.org/1999/xhtml" style="height: 100%; overflow-x: hidden; overflow-y: hidden;">
			<head>
				<title>SharePoint Viewer</title>
<!--				<meta http-equiv="pragma" content="no-cache" />-->
				<link type="text/css" rel="stylesheet" href="../css/sharepoint.css" />
				<link type="text/css" rel="stylesheet" href="../css/jquery.treeview.css" />
				
				<script src="../javascript/jquery.js" type="text/javascript"></script>
				<script src="../javascript/jquery-ui.js" type="text/javascript"></script>
				<script src="../javascript/jquery.layout.js" type="text/javascript"></script>
				<script src="../javascript/jquery.treeview.js" type="text/javascript"></script>
				
				<script type="text/javascript">
	
	var myLayout;
    
    $(document).ready(function () {
        myLayout = $('body').layout({
            
            west__showOverflowOnHover: false,
            west__minSize: 100,
            
            closable: false,
            resizable: true,
            slidable: false
            
            });
        
        $("#tree").treeview({
            persist: "location",
            collapsed: false,
            prerendered: false
        });
        
    });
				</script>
			</head>
			
			<body class="mainbody ui-layout-container" style="height: auto;">
				
				<div id="TreeDiv" class="ui-layout-west" style="height: auto;">
					<xsl:apply-templates select="parent"/>
					<ul id="tree" class="filetree" style="height: 100%; overflow: auto;">
						<xsl:call-template name="process_folder"/>
					</ul>
				</div>

				<div id="MainDiv" class="ui-layout-center" style="height: auto;">
					<iframe id="MainFrame" name="Main" width="100%" height="100%" style="border-style: hidden; border-width: 0px;" src="/view/sharepoint/blank.html"/>
				</div>
				
			</body>
			</html>

	</xsl:template>

	<xsl:template match="parent">
		<xsl:call-template name="link">
			<xsl:with-param name="class">folder</xsl:with-param>
		</xsl:call-template>
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
			<span class="{string($class)}">
		<xsl:choose>
			<xsl:when test="@pid">
				<xsl:choose>
					<xsl:when test="$class = 'folder'">
				<a href="{concat('viewer_',@pid,'.xml')}"><xsl:value-of select="@name"/></a>
					</xsl:when>
					<xsl:otherwise>
				<a href="{concat('http://aleph08.libis.kuleuven.be:8881/dtl-cgi/get_pid?redirect&amp;usagetype=VIEW_MAIN,VIEW,ARCHIVE&amp;pid=',@pid)}" target="Main">
					<xsl:value-of select="@name"/>
				</a>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<a href="/view/sharepoint/blank.html" target="Main"><xsl:value-of select="@name"/></a>
			</xsl:otherwise>
			</xsl:choose>
			<xsl:if test="@scope_ref">
				<a href="{concat('http://134.58.15.223/Query/detail.aspx?id=',@scope_ref)}"><img src="/view/sharepoint/scope.gif"/></a>
			</xsl:if>
			</span>
	</xsl:template>
	
</xsl:stylesheet>
