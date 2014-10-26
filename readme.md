# jQuery TodoGitHubby

Take a project as fun and complete as [TodoMVC](https://github.com/tastejs/todomvc/), cross it with GitHub's API and let a deranged developer splice the resulting genetic material to create Doctor Moureau's worst nightmare: TodoGitHubby: 50% ToDo list, 50% GitHub notifications. All in jQuery, all sleight of hands and slippery fingers!

> jQuery is a fast, small, and feature-rich JavaScript library. It makes things like HTML document traversal and manipulation, event handling, animation, and Ajax much simpler with an easy-to-use API that works across a multitude of browsers. With a combination of versatility and extensibility, jQuery has changed the way that millions of people write JavaScript.

> _[jQuery - jquery.com](http://jquery.com)_


## SetUp

I have created a new literal object in a var that I call soto_hack. Inside, three functions, the first one sets up the oAuth token for communicating with GitHub.

```javascript
var soto_hack = {
  github_setup: function () {
    $.ajaxSetup({
      beforeSend: function (xhr) {
        xhr.setRequestHeader('Authorization', 'token xxxxxxxxxxxxxxxxxxxxx');
      }
    });
  },
```
## Fetch all open issues

In esence we check for the existing issues and todos in local storage, fetch from github all the open issues and add them if not present locally already, finally we save to local storage again.

```javascript
fetch_issues: function () {
  this.github_setup();
  $.ajax({
    type: 'GET',
    url: 'https://api.github.com/issues',
    async: false,
    success: function (data, textStatus, jqXHR) {
      var all_todos = util.store('todos-jquery');
      var existing_issues = $.map(all_todos, function (e, i) { return e.repo + e.number; });
      var gh_todos = [];
      $.each(data, function (i, e) {
        if ($.inArray((e.repo + e.number), existing_issues) == -1) {
          var ght = {
            id: util.uuid(),
            title: e.title,
            completed: !e.state=='open',
            repo: e.repository.name,
            number: e.number
          };
          gh_todos = gh_todos.concat(ght);
        }
      });
      util.store('todos-jquery', all_todos.concat(gh_todos));
    }
  });
},
```

## Toggle Open/Close issues and todos

Everything happens in the jQuery ajax call to github to close/open an issue:

```javascript
  close_issue: function (ght) {
    var toggle_state;
    if (ght.completed == true) { toggle_state = {state: "open"}; }
    else { toggle_state = {state: "closed"}; };

    this.github_setup();
    $.ajax({
      type: 'PATCH',
      url: 'https://api.github.com/repos/sotoseattle/' + ght.repo + '/issues/' + ght.number,
      dataType: 'json',
      data: JSON.stringify(toggle_state),
      success: function (data, textStatus, jqXHR) { soto_hack.toggle_completion(ght); },
      error: function (xhr, ajaxOptions, thrownError) { console.log(xhr); }
    });
  },
```

In order to fire this request it, I have highjacked the App.toggle function to check if the issue is from github or made in the app. If the todo post comes originally from github, the ajax call is responsible for trying to close/open it and if successful, to change its completed attribute and render again.

In order to keep it as dry as possible I created a new function that toggles the completed attribute and renders the list. It is called from toggle and from close_issue, because both need it but under different circumstances.

```javascript
// soto_hack
toggle_completion: function (todo) {
  todo.completed = !todo.completed;
  App.render();
}

// App
toggle: function (e) {
  var i = this.indexFromEl(e.target);
  if (this.todos[i].repo != undefined) {
    soto_hack.close_issue(this.todos[i]);
  } else {
    soto_hack.toggle_completion(this.todos[i])
  }
},
```
The functionality implemented allows to reopen any closed issues that are still present in the local storage. So, although we only fetch the open ones in github, once we have them locally and we track them, even if closed we can reopen them.

## Toggle All


