/**
 * Copyright (c) 2009 - 2010 Chris Leonello
 * jqPlot is currently available for use in all personal or commercial projects 
 * under both the MIT (http://www.opensource.org/licenses/mit-license.php) and GPL 
 * version 2.0 (http://www.gnu.org/licenses/gpl-2.0.html) licenses. This means that you can 
 * choose the license that best suits your project and use it accordingly. 
 *
 * Although not required, the author would appreciate an email letting him 
 * know of any substantial use of jqPlot.  You can reach the author at: 
 * chris at jqplot  or see http://www.jqplot.com/info.php .
 *
 * If you are feeling kind and generous, consider supporting the project by
 * making a donation at: http://www.jqplot.com/donate.php .
 *
 * jqPlot includes date instance methods and printf/sprintf functions by other authors:
 *
 * Date instance methods contained in jqplot.dateMethods.js:
 *
 *     author Ken Snyder (ken d snyder at gmail dot com)
 *     date 2008-09-10
 *     version 2.0.2 (http://kendsnyder.com/sandbox/date/)     
 *     license Creative Commons Attribution License 3.0 (http://creativecommons.org/licenses/by/3.0/)
 *
 * JavaScript printf/sprintf functions contained in jqplot.sprintf.js:
 *
 *     version 2007.04.27
 *     author Ash Searle
 *     http://hexmen.com/blog/2007/03/printf-sprintf/
 *     http://hexmen.com/js/sprintf.js
 *     The author (Ash Searle) has placed this code in the public domain:
 *     "This code is unrestricted: you are free to use it however you like."
 * 
 */
(function(c){c.jqplot.PointLabels=function(e){this.show=c.jqplot.config.enablePlugins;this.location="n";this.labelsFromSeries=false;this.seriesLabelIndex=null;this.labels=[];this._labels=[];this.stackedValue=false;this.ypadding=6;this.xpadding=6;this.escapeHTML=true;this.edgeTolerance=-5;this.formatter=c.jqplot.DefaultTickFormatter;this.formatString="";this.hideZeros=false;this._elems=[];c.extend(true,this,e)};var a=["nw","n","ne","e","se","s","sw","w"];var d={nw:0,n:1,ne:2,e:3,se:4,s:5,sw:6,w:7};var b=["se","s","sw","w","nw","n","ne","e"];c.jqplot.PointLabels.init=function(i,h,f,g){var e=c.extend(true,{},f,g);e.pointLabels=e.pointLabels||{};if(this.renderer.constructor==c.jqplot.BarRenderer&&this.barDirection=="horizontal"&&!e.pointLabels.location){e.pointLabels.location="e"}this.plugins.pointLabels=new c.jqplot.PointLabels(e.pointLabels);this.plugins.pointLabels.setLabels.call(this)};c.jqplot.PointLabels.prototype.setLabels=function(){var f=this.plugins.pointLabels;var h;if(f.seriesLabelIndex!=null){h=f.seriesLabelIndex}else{if(this.renderer.constructor==c.jqplot.BarRenderer&&this.barDirection=="horizontal"){h=0}else{h=this._plotData[0].length-1}}f._labels=[];if(f.labels.length==0||f.labelsFromSeries){if(f.stackedValue){if(this._plotData.length&&this._plotData[0].length){for(var e=0;e<this._plotData.length;e++){f._labels.push(this._plotData[e][h])}}}else{var g=this.data;if(this.renderer.constructor==c.jqplot.BarRenderer&&this.waterfall){g=this._data}if(g.length&&g[0].length){for(var e=0;e<g.length;e++){f._labels.push(g[e][h])}}}}else{if(f.labels.length){f._labels=f.labels}}};c.jqplot.PointLabels.prototype.xOffset=function(f,e,g){e=e||this.location;g=g||this.xpadding;var h;switch(e){case"nw":h=-f.outerWidth(true)-this.xpadding;break;case"n":h=-f.outerWidth(true)/2;break;case"ne":h=this.xpadding;break;case"e":h=this.xpadding;break;case"se":h=this.xpadding;break;case"s":h=-f.outerWidth(true)/2;break;case"sw":h=-f.outerWidth(true)-this.xpadding;break;case"w":h=-f.outerWidth(true)-this.xpadding;break;default:h=-f.outerWidth(true)-this.xpadding;break}return h};c.jqplot.PointLabels.prototype.yOffset=function(f,e,g){e=e||this.location;g=g||this.xpadding;var h;switch(e){case"nw":h=-f.outerHeight(true)-this.ypadding;break;case"n":h=-f.outerHeight(true)-this.ypadding;break;case"ne":h=-f.outerHeight(true)-this.ypadding;break;case"e":h=-f.outerHeight(true)/2;break;case"se":h=this.ypadding;break;case"s":h=this.ypadding;break;case"sw":h=this.ypadding;break;case"w":h=-f.outerHeight(true)/2;break;default:h=-f.outerHeight(true)-this.ypadding;break}return h};c.jqplot.PointLabels.draw=function(t,h){var r=this.plugins.pointLabels;r.setLabels.call(this);for(var s=0;s<r._elems.length;s++){r._elems[s].remove()}if(r.show){var o="_"+this._stackAxis+"axis";if(!r.formatString){r.formatString=this[o]._ticks[0].formatString;r.formatter=this[o]._ticks[0].formatter}var z=this._plotData;var w=this._xaxis;var n=this._yaxis;for(var s=r._labels.length-1;s>=0;s--){var m=r._labels[s];if(r.hideZeros&&parseInt(r._labels[s],10)==0){m=""}if(m!=null){m=r.formatter(r.formatString,m)}var v=c('<div class="jqplot-point-label jqplot-series-'+this.index+" jqplot-point-"+s+'" style="position:absolute"></div>');v.insertAfter(t.canvas);r._elems.push(v);if(r.escapeHTML){v.text(m)}else{v.html(m)}var f=r.location;if(this.waterfall&&parseInt(m,10)<0){f=b[d[f]]}var l=w.u2p(z[s][0])+r.xOffset(v,f);var g=n.u2p(z[s][1])+r.yOffset(v,f);if(this.renderer.constructor==c.jqplot.BarRenderer){if(this.barDirection=="vertical"){l+=this._barNudge}else{g-=this._barNudge}}v.css("left",l);v.css("top",g);var j=l+c(v).width();var q=g+c(v).height();var y=r.edgeTolerance;var e=c(t.canvas).position().left;var u=c(t.canvas).position().top;var x=t.canvas.width+e;var k=t.canvas.height+u;if(l-y<e||g-y<u||j+y>x||q+y>k){c(v).detach()}}}};c.jqplot.postSeriesInitHooks.push(c.jqplot.PointLabels.init);c.jqplot.postDrawSeriesHooks.push(c.jqplot.PointLabels.draw)})(jQuery);