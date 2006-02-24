<?xml version='1.0'?> 
<xsl:stylesheet  
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:date="http://exslt.org/dates-and-times"
    exclude-result-prefixes="date" > 

        <xsl:import href="chunk.xsl"/> 

        <xsl:param name="html.stylesheet" select="'style.css'"/> 
        <xsl:param name="shade.verbatim" select="1"/>
        <xsl:param name="chapter.autolabel" select="1"/>
        <xsl:param name="section.autolabel" select="1"/>
        <xsl:param name="appendix.autolabel" select="1"/>
        <xsl:param name="use.id.as.filename" select="1"/>
        <xsl:param name="chunker.output.encoding" select="UTF-8"/>
        <xsl:param name="admon.graphics" select="1"/>
<xsl:attribute-set name="shade.verbatim.style">
  <xsl:attribute name="border">0</xsl:attribute>
  <xsl:attribute name="width">100%</xsl:attribute>
  <xsl:attribute name="bgcolor">#E0E0E0</xsl:attribute>
</xsl:attribute-set>


<xsl:template name="user.head.content">  
  <meta name="date">  
    <xsl:attribute name="content">  
      <xsl:call-template name="datetime.format">  
        <xsl:with-param name="date" select="date:date-time()"/>  
        <xsl:with-param name="format" select="'m/d/Y'"/>  
      </xsl:call-template>
    </xsl:attribute>
  </meta>
</xsl:template>

</xsl:stylesheet>
