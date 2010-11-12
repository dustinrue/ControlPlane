function showCrashID (crashid) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=getlogcrashid&id=" + crashid,
        success: function(data) {
            data = data.replace(/(\r\n|\n|\r)/gm, "<br/>");
            $('#logarea').html("<pre>" + data + "</pre>");
        }
    });
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=getdescriptioncrashid&id=" + crashid,
        success: function(data) {
            data = data.replace(/(\r\n|\n|\r)/gm, "<br/>");
            $('#descriptionarea').html("<pre>" + data + "</pre>");
        }
    });
}

function deleteCrashID (crashid, groupid) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=deletecrashid&id=" + crashid + "&groupid=" + groupid,
        success: function(data) {
            if (data == "") {
                $('#crashrow' + crashid).remove();
            } else {
                alert('ERROR: ' + data);
            }
        }
    });
}

function deleteGroupID (groupid) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=deletegroupid&id=" + groupid,
        success: function(data) {
            if (data == "") {
                $('#grouprow' + groupid).remove();
            } else {
                alert('ERROR: ' + data);
            }
        }
    });
}

function deleteGroups (bundleidentifier, version) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=deletegroups&bundleidentifier=" + bundleidentifier + "&version=" + version,
        success: function(data) {
            if (data == "") {
                $('#groups').remove();
            } else {
                alert('ERROR: ' + data);
            }
        }
    });
}

function symbolicateCrashID (crashid) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: "action=symbolicatecrashid&id=" + crashid,
        success: function(data) {
            if (data == "") {
                $("#symbolicate" + crashid).html('Symbolicating...');
            } else {
                alert('ERROR: ' + data);
            }
        }
    });
}

function updateGroupMeta (groupid, bundleidentifier) {
    $.ajax({
        type: "POST",
        url: 'actionapi.php',
        data: ({
            action: 'updategroupid', 
            id: groupid, 
            bundleidentifier: bundleidentifier, 
            fixversion: $("#fixversion" + groupid).val(), 
            description: $("#description" + groupid).val()
        }),
        success: function(data) {
            if (data != "") {
                alert('ERROR: ' + data);
            }
        }
    });
}
