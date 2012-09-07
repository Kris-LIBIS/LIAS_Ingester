function setCookie(c_name, value, exdays) {
    var exdate = new Date();
    exdate.setDate(exdate.getDate() + exdays);
    var c_value = value + ((exdays == null) ? "" : "; expires=" + exdate.toUTCString());
    document.cookie = c_name + "=" + c_value;
}

function getCookie(c_name) {
    var i, x, y, ARRcookies = document.cookie.split(";");
    for (i = 0; i < ARRcookies.length; i++) {
        x = ARRcookies[i].substr(0, ARRcookies[i].indexOf("="));
        y = ARRcookies[i].substr(ARRcookies[i].indexOf("=") + 1);
        x = x.replace(/^\s+|\s+$/g, "");
        if (x == c_name) {
            return y;
        }
    }
    return null;
}

function setDefaultCookie(c_name, value, exdays) {
    if (getCookie(c_name) == null) {
        setCookie(c_name,value,exdays);
    }
}

function deleteCookie(c_name) {
    document.cookie = c_name + '=; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
}

function initialize_layout() {
    $('body').layout({
        west__showOverflowOnHover: false,
        west__minSize: 100,
        closable: false,
        resizable: true,
        slidable: false
    });
}

function initialize_tree() {
    $("#tree").treeview({
        persist: "location",
        collapsed: false,
        prerendered: false
    });
}

function get_first_file() {
    var files = $('ul li.file');
    if (files.length == 0) {
        return null;
    }
    return files[0];
}

function select_file(node) {
    $('li.current').removeClass('currrent');
    node.addClass('current');

}

function select_next_file() {
    var target = get_next_file();
    if (target != null) {
        select_file(target);
    }
}

function get_next_file() {
    var current = $('li.current');
    if (current == null) {
        current = get_first_file();
    }

    var folder = $('#tree');
    if (current != null) {
        var next_is_target = false;
        for (child in folder.children()) {
            if (child.className = 'file') {
                if (next_is_target) {
                    return child;
                }
                if (child == current) {
                    next_is_target = true;
                }
            }
        }
    }
    return current;
}

function get_path(node) {
    var path = node.getAttribute('name');
    while (node.parentNode != null) {
        node = node.parentNode;
        path = node.getAttribute('name') +'/' + path;
    }
    path = getCookie('current_root') + '/' + path;
    return path;
}

$(document).ready(function () {
    initialize_tree();
    setTimeout("initialize_layout()", 5);
    select_next_file();
    setDefaultCookie('current_root', '', 0.1);
});
