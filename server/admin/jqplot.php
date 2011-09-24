    $.jqplot.config.enablePlugins = true;
<?php
    if ($platformticks != "") {
?>
    line1 = [<?php echo $platformvalues; ?>];
    plot1 = $.jqplot('platformdiv', [line1], {
        seriesDefaults: {
                renderer:$.jqplot.BarRenderer
            },
        axesDefaults: {
          tickRenderer: $.jqplot.CanvasAxisTickRenderer,
          tickOptions: { fontSize: '9px'}          
        },
        axes:{
            xaxis:{
                renderer:$.jqplot.CategoryAxisRenderer,
                ticks:[<?php echo $platformticks; ?>],
                tickOptions: { angle: -30}
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {show: false}
    });
<?php
    }
    
    if (sizeof($crashvaluesarray) > 0) {
        foreach ($crashvaluesarray as $key => $value) {
            if ($crashvalues != "") $crashvalues = $crashvalues.", ";
            $crashvalues .= "['".$key."', ".$value."]";
        }
?>
    line1 = [<?php echo $crashvalues; ?>];
    plot1 = $.jqplot('crashdiv', [line1], {
        seriesDefaults: {showMarker:false},
        series:[
            {pointLabels:{
                show: false
            }}],
        axes:{
            xaxis:{
                renderer:$.jqplot.DateAxisRenderer,
                rendererOptions:{tickRenderer:$.jqplot.CanvasAxisTickRenderer},
                tickOptions:{formatString:'%m/%d',fontSize: '9px' }
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {show: false}
    });
<?php
    }
    
    if ($osticks != "") {
?>
    line1 = [<?php echo $osvalues; ?>];
    plot1 = $.jqplot('osdiv', [line1], {
        seriesDefaults: {
                renderer:$.jqplot.BarRenderer
            },
        axesDefaults: {
          tickRenderer: $.jqplot.CanvasAxisTickRenderer,
          tickOptions: { fontSize: '9px'}          
        },
        axes:{
            xaxis:{
                renderer:$.jqplot.CategoryAxisRenderer,
                ticks:[<?php echo $osticks; ?>],
                tickOptions: { angle: -30}
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {show: false}
    });
<?php
    }
?>