`/*global jQuery, Handlebars */`
$ ->
  Handlebars.registerHelper 'eq', (a, b, options) ->
    if a == b then options.fn(@) else options.inverse(@);
  ENTER_KEY = 13
  ESCAPE_KEY = 27
  util =
    uuid: ->
      uuid = ''
      for i in [0...32]
        random = Math.random() * 16 | 0;
        uuid += '-' if (i == 8 || i == 12 || i == 16 || i == 20)
        uuid += (if i == 12 then 4 else (if i == 16 then (random & 3 | 8) else random)).toString(16)
      uuid
    pluralize: (count, word) ->
      if count == 1 then word else (word + 's')
    store: (namespace, data) ->
      if arguments.length > 1
        localStorage.setItem(namespace, JSON.stringify(data));
      else
        store = localStorage.getItem(namespace)
        (store && JSON.parse(store)) || []
  soto_hack =
    github_setup: ->
      $.ajaxSetup
        dataType: "json"
        contentType: "application/json: charset=utf-8"
        cache: true
        beforeSend: (xhr) ->
          xhr.setRequestHeader 'Authorization', 'token xxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    fetch_issues: ->
      $.ajax
        type: 'GET'
        url: 'https://api.github.com/issues'
        async: false
        success: (data, textStatus, jqXHR) ->
          all_todos = util.store('todos-jquery')
          existing_issues = all_todos.map (e, i) ->  ('' + e.repo + e.number)
          gh_todos = []
          for e in data
            if ('' + e.repository.name + e.number) not in existing_issues
              ght =
                id: util.uuid
                title: e.title
                completed: !e.state=='open'
                repo: e.repository.name
                number: e.number
              gh_todos = gh_todos.concat(ght)
          util.store('todos-jquery', all_todos.concat(gh_todos))
    close_issue: (ght) ->
      toggle_state = if (ght.completed == true) then {state: "open"} else {state: "closed"}
      $.ajax
        type: 'PATCH',
        url: 'https://api.github.com/repos/sotoseattle/' + ght.repo + '/issues/' + ght.number,
        dataType: 'json',
        data: JSON.stringify(toggle_state),
        success: (data, textStatus, jqXHR) ->
          soto_hack.toggle_completion(ght)
        error: (xhr, ajaxOptions, thrownError) ->
          console.log(xhr)
    toggle_completion: (todo) ->
      todo.completed = !todo.completed
      App.render
  `
  var App = {
    init: function () {
      soto_hack.github_setup();
      soto_hack.fetch_issues();
      this.todos = util.store('todos-jquery');
      this.cacheElements();
      this.bindEvents();

      Router({
        '/:filter': function (filter) {
          this.filter = filter;
          this.render();
        }.bind(this)
      }).init('/all');
    },

    cacheElements: function () {
      this.todoTemplate = Handlebars.compile($('#todo-template').html());
      this.footerTemplate = Handlebars.compile($('#footer-template').html());
      this.$todoApp = $('#todoapp');
      this.$header = this.$todoApp.find('#header');
      this.$main = this.$todoApp.find('#main');
      this.$footer = this.$todoApp.find('#footer');
      this.$newTodo = this.$header.find('#new-todo');
      this.$toggleAll = this.$main.find('#toggle-all');
      this.$todoList = this.$main.find('#todo-list');
      this.$count = this.$footer.find('#todo-count');
      this.$clearBtn = this.$footer.find('#clear-completed');
    },
    bindEvents: function () {
      var list = this.$todoList;
      this.$newTodo.on('keyup', this.create.bind(this));
      this.$toggleAll.on('change', this.toggleAll.bind(this));
      this.$footer.on('click', '#clear-completed', this.destroyCompleted.bind(this));
      list.on('change', '.toggle', this.toggle.bind(this));
      list.on('dblclick', 'label', this.edit.bind(this));
      list.on('keyup', '.edit', this.editKeyup.bind(this));
      list.on('focusout', '.edit', this.update.bind(this));
      list.on('click', '.destroy', this.destroy.bind(this));
    },
    render: function () {
      var todos = this.getFilteredTodos();
      this.$todoList.html(this.todoTemplate(todos));
      this.$main.toggle(todos.length > 0);
      this.$toggleAll.prop('checked', this.getActiveTodos().length === 0);
      this.renderFooter();
      this.$newTodo.focus();
      util.store('todos-jquery', this.todos);
    },
    renderFooter: function () {
      var todoCount = this.todos.length;
      var activeTodoCount = this.getActiveTodos().length;
      var template = this.footerTemplate({
        activeTodoCount: activeTodoCount,
        activeTodoWord: util.pluralize(activeTodoCount, 'item'),
        completedTodos: todoCount - activeTodoCount,
        filter: this.filter
      });

      this.$footer.toggle(todoCount > 0).html(template);
    },
    toggleAll: function (e) {
      var isChecked = $(e.target).prop('checked');

      this.todos.forEach(function (todo) {
        todo.completed = isChecked;
      });

      this.render();
    },
    getActiveTodos: function () {
      return this.todos.filter(function (todo) {
        return !todo.completed;
      });
    },
    getCompletedTodos: function () {
      return this.todos.filter(function (todo) {
        return todo.completed;
      });
    },
    getFilteredTodos: function () {
      if (this.filter === 'active') {
        return this.getActiveTodos();
      }

      if (this.filter === 'completed') {
        return this.getCompletedTodos();
      }

      return this.todos;
    },
    destroyCompleted: function () {
      this.todos = this.getActiveTodos();
      this.filter = 'all';
      this.render();
    },
    indexFromEl: function (el) {
      var id = $(el).closest('li').data('id');
      var todos = this.todos;
      var i = todos.length;

      while (i--) {
        if (todos[i].id === id) {
          return i;
        }
      }
    },
    create: function (e) {
      var $input = $(e.target);
      var val = $input.val().trim();

      if (e.which !== ENTER_KEY || !val) {
        return;
      }

      this.todos.push({
        id: util.uuid(),
        title: val,
        completed: false
      });

      $input.val('');

      this.render();
    },
    toggle: function (e) {
      var i = this.indexFromEl(e.target);
      if (this.todos[i].repo != undefined) {
        soto_hack.close_issue(this.todos[i]);
      } else {
        soto_hack.toggle_completion(this.todos[i])
      }
    },
    edit: function (e) {
      var $input = $(e.target).closest('li').addClass('editing').find('.edit');
      $input.val($input.val()).focus();
    },
    editKeyup: function (e) {
      if (e.which === ENTER_KEY) {
        e.target.blur();
      }

      if (e.which === ESCAPE_KEY) {
        $(e.target).data('abort', true).blur();
      }
    },
    update: function (e) {
      var el = e.target;
      var $el = $(el);
      var val = $el.val().trim();

      if ($el.data('abort')) {
        $el.data('abort', false);
        this.render();
        return;
      }

      var i = this.indexFromEl(el);

      if (val) {
        this.todos[i].title = val;
      } else {
        this.todos.splice(i, 1);
      }

      this.render();
    },
    destroy: function (e) {
      this.todos.splice(this.indexFromEl(e.target), 1);
      this.render();
    }
  };

  App.init();`
