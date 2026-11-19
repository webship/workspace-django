"""The Django test site: settings for its container, the polls app, sample data and accounts.

Run with the site's Python, in the folder of manage.py, in the project's container:

    python django-site.py settings          write site_settings.py and import it at the end of settings.py
    python django-site.py polls             write the polls app of the official tutorial, registered in the admin
    python django-site.py seed              the sample categories, tags and questions of the polls app
    python django-site.py accounts <verb>   owner, add, cancel, list or installed

The accounts come as base64 of a JSON object in DJANGO_SITE_ACCOUNTS, so no password is written
into a file of the project and no quoting can break a value:

    {"owner": {"name": ..., "email": ..., "password": ...},
     "accounts": [{"name": ..., "email": ..., "password": ..., "role": "superuser|editor|viewer"}]}

The polls app is the one the official Django tutorial builds (parts 1 to 8, Django documentation,
BSD licence: see POLLS-LICENSE beside this script), with what the admin of most projects uses added
to it: a category (an autocomplete field, a stacked inline, a protected relation), tags (a two-list
selector), a read-only field, a date drill-down, pagination and an action. Nothing here is specific
to one release line: the same files run on Django 5.2 (the long-term-support line) and 6.1.
"""

import base64
import datetime
import json
import os
import re
import sys
from pathlib import Path

HERE = Path.cwd()


def project_package():
    """The package of the project: the one manage.py names in DJANGO_SETTINGS_MODULE."""
    manage = (HERE / "manage.py").read_text()
    match = re.search(r"DJANGO_SETTINGS_MODULE['\"],\s*['\"]([\w.]+)\.settings['\"]", manage)
    if not match:
        sys.exit("manage.py names no settings module: run this in the folder of manage.py.")
    return match.group(1)


def setup_django():
    sys.path.insert(0, str(HERE))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", project_package() + ".settings")
    import django

    django.setup()


# ---------------------------------------------------------------------------------------------
# settings
# ---------------------------------------------------------------------------------------------

SITE_SETTINGS = '''"""Settings for the site in its container (written by django-site.py settings).

settings.py imports this file last, so what is set here wins. It is yours to change.
"""

# The site is reached through the router of the container tool, over https.
ALLOWED_HOSTS = ["*"]
CSRF_TRUSTED_ORIGINS = ["https://*.ddev.site", "http://*.ddev.site", "http://localhost:8000", "http://127.0.0.1:8000"]
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# Off, as in production: a missing page is the site's 404 page, a refusal its 403 page, never a
# debug page. The server is started with --insecure, which keeps it serving the static files.
# Set it to True while you develop.
DEBUG = False

# The database of the project's container.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "db",
        "USER": "db",
        "PASSWORD": "db",
        "HOST": "db",
        "PORT": "5432",
    }
}

# The mailbox of the project's container: no e-mail leaves the machine. Django 6.1 configures
# mail with MAILERS (startproject writes one, to the console), older lines with EMAIL_HOST.
import django  # noqa: E402

if django.VERSION >= (6, 1):
    MAILERS = {
        "default": {
            "BACKEND": "django.core.mail.backends.smtp.EmailBackend",
            "OPTIONS": {"host": "127.0.0.1", "port": 1025},
        }
    }
else:
    EMAIL_HOST = "127.0.0.1"
    EMAIL_PORT = 1025
'''


def write_settings():
    package = HERE / project_package()
    (package / "site_settings.py").write_text(SITE_SETTINGS)
    settings = package / "settings.py"
    text = settings.read_text()
    if "site_settings" not in text:
        settings.write_text(text.rstrip("\n") + "\n\nfrom .site_settings import *  # noqa: E402,F401,F403\n")
    print("settings: %s/site_settings.py" % package.name)


# ---------------------------------------------------------------------------------------------
# polls
# ---------------------------------------------------------------------------------------------

POLLS = {
    "polls/__init__.py": "",
    "polls/apps.py": '''from django.apps import AppConfig


class PollsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "polls"
''',
    "polls/models.py": '''import datetime

from django.contrib import admin
from django.db import models
from django.utils import timezone


class Category(models.Model):
    """Added to the tutorial's app: an autocomplete field, a stacked inline, a protected relation."""

    name = models.CharField(max_length=100, unique=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Tag(models.Model):
    """Added to the tutorial's app: a two-list selector."""

    name = models.CharField(max_length=50, unique=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Question(models.Model):
    question_text = models.CharField(max_length=200)
    pub_date = models.DateTimeField("date published")
    # Added to the tutorial's model: a question in a category that has questions cannot be
    # deleted with it (PROTECT), and its tags.
    category = models.ForeignKey(Category, on_delete=models.PROTECT, null=True, blank=True)
    tags = models.ManyToManyField(Tag, blank=True)

    def __str__(self):
        return self.question_text

    @admin.display(
        boolean=True,
        ordering="pub_date",
        description="Published recently?",
    )
    def was_published_recently(self):
        now = timezone.now()
        return now - datetime.timedelta(days=1) <= self.pub_date <= now

    @admin.display(description="Total votes")
    def total_votes(self):
        return sum(choice.votes for choice in self.choice_set.all())


class Choice(models.Model):
    question = models.ForeignKey(Question, on_delete=models.CASCADE)
    choice_text = models.CharField(max_length=200)
    votes = models.IntegerField(default=0)

    def __str__(self):
        return self.choice_text
''',
    "polls/admin.py": '''from django.contrib import admin, messages
from django.utils.translation import ngettext

from .models import Category, Choice, Question, Tag


class ChoiceInline(admin.TabularInline):
    model = Choice
    extra = 3


@admin.action(description="Reset the votes of the selected questions", permissions=["change"])
def reset_votes(modeladmin, request, queryset):
    count = queryset.count()
    Choice.objects.filter(question__in=queryset).update(votes=0)
    modeladmin.message_user(
        request,
        ngettext("The votes of %d question were reset.", "The votes of %d questions were reset.", count) % count,
        messages.SUCCESS,
    )


@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    # The tutorial's admin (part 7): fieldsets, the inline choices, list_display, list_filter,
    # search_fields. Added to it: the classification and results fieldsets, a read-only field,
    # an autocomplete field, a two-list selector, a date drill-down, pagination and an action.
    fieldsets = [
        (None, {"fields": ["question_text"]}),
        ("Date information", {"fields": ["pub_date"], "classes": ["collapse"]}),
        ("Classification", {"fields": ["category", "tags"]}),
        ("Results", {"fields": ["total_votes"]}),
    ]
    readonly_fields = ["total_votes"]
    inlines = [ChoiceInline]
    list_display = ["question_text", "pub_date", "category", "was_published_recently"]
    list_filter = ["pub_date", "category"]
    search_fields = ["question_text"]
    date_hierarchy = "pub_date"
    list_per_page = 10
    autocomplete_fields = ["category"]
    filter_horizontal = ["tags"]
    actions = [reset_votes]


class QuestionInline(admin.StackedInline):
    model = Question
    fields = ["question_text", "pub_date"]
    extra = 1


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    search_fields = ["name"]
    inlines = [QuestionInline]


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    search_fields = ["name"]
''',
    "polls/views.py": '''from django.db.models import F
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.utils import timezone
from django.views import generic

from .models import Choice, Question


class IndexView(generic.ListView):
    template_name = "polls/index.html"
    context_object_name = "latest_question_list"

    def get_queryset(self):
        """
        Return the last five published questions (not including those set to be
        published in the future).
        """
        return Question.objects.filter(pub_date__lte=timezone.now()).order_by("-pub_date")[:5]


class DetailView(generic.DetailView):
    model = Question
    template_name = "polls/detail.html"

    def get_queryset(self):
        """
        Excludes any questions that aren't published yet.
        """
        return Question.objects.filter(pub_date__lte=timezone.now())


class ResultsView(generic.DetailView):
    model = Question
    template_name = "polls/results.html"


def vote(request, question_id):
    question = get_object_or_404(Question, pk=question_id)
    try:
        selected_choice = question.choice_set.get(pk=request.POST["choice"])
    except (KeyError, Choice.DoesNotExist):
        # Redisplay the question voting form.
        return render(
            request,
            "polls/detail.html",
            {
                "question": question,
                "error_message": "You didn't select a choice.",
            },
        )
    else:
        selected_choice.votes = F("votes") + 1
        selected_choice.save()
        # Always return an HttpResponseRedirect after successfully dealing
        # with POST data. This prevents data from being posted twice if a
        # user hits the Back button.
        return HttpResponseRedirect(reverse("polls:results", args=(question.id,)))
''',
    "polls/urls.py": '''from django.urls import path

from . import views

app_name = "polls"
urlpatterns = [
    path("", views.IndexView.as_view(), name="index"),
    path("<int:pk>/", views.DetailView.as_view(), name="detail"),
    path("<int:pk>/results/", views.ResultsView.as_view(), name="results"),
    path("<int:question_id>/vote/", views.vote, name="vote"),
]
''',
    "polls/templates/polls/index.html": '''{% load static %}

<link rel="stylesheet" href="{% static 'polls/style.css' %}">

{% if latest_question_list %}
    <ul>
    {% for question in latest_question_list %}
        <li><a href="{% url 'polls:detail' question.id %}">{{ question.question_text }}</a></li>
    {% endfor %}
    </ul>
{% else %}
    <p>No polls are available.</p>
{% endif %}
''',
    "polls/templates/polls/detail.html": '''<form action="{% url 'polls:vote' question.id %}" method="post">
{% csrf_token %}
<fieldset>
    <legend><h1>{{ question.question_text }}</h1></legend>
    {% if error_message %}<p><strong>{{ error_message }}</strong></p>{% endif %}
    {% for choice in question.choice_set.all %}
        <input type="radio" name="choice" id="choice{{ forloop.counter }}" value="{{ choice.id }}">
        <label for="choice{{ forloop.counter }}">{{ choice.choice_text }}</label><br>
    {% endfor %}
</fieldset>
<input type="submit" value="Vote">
</form>
''',
    "polls/templates/polls/results.html": '''<h1>{{ question.question_text }}</h1>

<ul>
{% for choice in question.choice_set.all %}
    <li>{{ choice.choice_text }} -- {{ choice.votes }} vote{{ choice.votes|pluralize }}</li>
{% endfor %}
</ul>

<a href="{% url 'polls:detail' question.id %}">Vote again?</a>
''',
    "polls/static/polls/style.css": '''li a {
    color: green;
}
''',
}


def write_polls():
    for name, text in POLLS.items():
        target = HERE / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    package = HERE / project_package()
    settings = package / "settings.py"
    text = settings.read_text()
    if "polls.apps.PollsConfig" not in text:
        text, count = re.subn(r"INSTALLED_APPS\s*=\s*\[", 'INSTALLED_APPS = [\n    "polls.apps.PollsConfig",', text, count=1)
        if not count:
            sys.exit("settings.py has no INSTALLED_APPS list to add the polls app to.")
        settings.write_text(text)
    urls = package / "urls.py"
    text = urls.read_text()
    if "polls.urls" not in text:
        text = text.replace("from django.urls import path", "from django.urls import include, path")
        text, count = re.subn(r"urlpatterns\s*=\s*\[", 'urlpatterns = [\n    path("polls/", include("polls.urls")),', text, count=1)
        if not count:
            sys.exit("urls.py has no urlpatterns list to add the polls URLs to.")
        urls.write_text(text)
    print("polls: the app, in INSTALLED_APPS and at /polls/")


# ---------------------------------------------------------------------------------------------
# seed
# ---------------------------------------------------------------------------------------------

CATEGORIES = ["Food", "Music", "Science", "Sport", "Travel"]
TAGS = ["Fun", "Long", "Quick", "Serious"]
# question text, publication date (UTC), category, tags, choices with their votes. The first is the
# tutorial's own question.
QUESTIONS = [
    ("What's up?", "2025-01-06 09:00", None, ["Fun", "Quick"], [("Not much", 3), ("The sky", 5)]),
    ("Which fruit do you eat most?", "2025-02-03 10:00", "Food", ["Quick"], [("Apples", 4), ("Bananas", 2), ("Oranges", 1)]),
    ("How often do you cook at home?", "2025-03-10 11:00", "Food", ["Serious"], [("Every day", 6), ("Once a week", 2)]),
    ("Which bread do you like best?", "2025-04-14 12:00", "Food", ["Fun"], [("White", 1), ("Brown", 3)]),
    ("Which instrument would you learn?", "2025-05-05 09:30", "Music", ["Fun", "Long"], [("Piano", 5), ("Guitar", 4), ("Violin", 2)]),
    ("How do you listen to music?", "2025-06-09 10:30", "Music", ["Quick"], [("Radio", 1), ("Records", 2), ("Streaming", 7)]),
    ("Which concert hall sounds best?", "2025-07-07 11:30", "Music", ["Serious", "Long"], [("The old one", 2), ("The new one", 2)]),
    ("Which planet would you visit first?", "2025-08-04 12:30", "Science", ["Fun"], [("Mars", 8), ("Venus", 1)]),
    ("Is the Moon moving away from the Earth?", "2025-09-08 13:30", "Science", ["Serious"], [("Yes", 6), ("No", 1)]),
    ("Which element is the most common in the universe?", "2025-10-06 14:30", "Science", ["Serious", "Quick"], [("Hydrogen", 9), ("Helium", 2)]),
    ("Which sport do you watch most?", "2025-11-03 15:30", "Sport", ["Fun"], [("Football", 6), ("Tennis", 3)]),
    ("How many times a week do you exercise?", "2025-12-01 16:30", "Sport", ["Serious"], [("Never", 1), ("Twice", 4), ("Every day", 2)]),
    ("Which city would you visit next?", "2026-01-12 09:15", "Travel", ["Fun", "Long"], [("Paris", 4), ("Rome", 3), ("Cairo", 3)]),
    ("Do you travel by train or by plane?", "2026-01-26 10:15", "Travel", ["Quick"], [("Train", 5), ("Plane", 4)]),
    ("Which river is the longest?", "2026-02-09 11:15", "Science", ["Serious"], [("The Nile", 6), ("The Amazon", 5)]),
    ("Which season do you like best?", "2026-02-23 12:15", None, ["Fun"], [("Spring", 3), ("Autumn", 4)]),
    ("Which team sport is the oldest?", "2026-03-09 13:15", "Sport", ["Long"], [("Hurling", 2), ("Polo", 2)]),
    ("Where would you go for a quiet week?", "2026-03-23 14:15", "Travel", ["Long"], [("The mountains", 5), ("The sea", 5)]),
    ("Which spice do you cook with most?", "2026-04-06 15:15", "Food", ["Quick"], [("Cumin", 3), ("Pepper", 6)]),
    ("Which song do you sing in the shower?", "2026-04-20 16:15", "Music", ["Fun", "Quick"], [("A happy one", 4), ("A sad one", 1)]),
    ("How far is the nearest star?", "2026-05-04 09:45", "Science", ["Serious", "Long"], [("About four light years", 7), ("About one light year", 1)]),
    ("Which race would you run?", "2026-05-18 10:45", "Sport", ["Long"], [("A mile", 3), ("A marathon", 2)]),
    ("Which train journey is the most beautiful?", "2026-06-01 11:45", "Travel", ["Fun", "Long"], [("Along the coast", 6), ("Through the mountains", 6)]),
    ("Which breakfast keeps you going?", "2026-06-15 12:45", "Food", ["Serious"], [("Porridge", 5), ("Eggs", 4)]),
]


def seed():
    setup_django()
    from django.apps import apps
    from django.utils import timezone

    if not apps.is_installed("polls"):
        sys.exit("The polls app is not installed: write it first (django-site.py polls).")
    Category = apps.get_model("polls", "Category")
    Tag = apps.get_model("polls", "Tag")
    Question = apps.get_model("polls", "Question")
    categories = {name: Category.objects.get_or_create(name=name)[0] for name in CATEGORIES}
    tags = {name: Tag.objects.get_or_create(name=name)[0] for name in TAGS}
    made = 0
    for text, when, category, tag_names, choices in QUESTIONS:
        if Question.objects.filter(question_text=text).exists():
            continue
        pub_date = datetime.datetime.strptime(when, "%Y-%m-%d %H:%M").replace(tzinfo=datetime.timezone.utc)
        question = Question.objects.create(
            question_text=text,
            pub_date=pub_date.astimezone(timezone.get_current_timezone()),
            category=categories[category] if category else None,
        )
        question.tags.set([tags[name] for name in tag_names])
        for choice_text, votes in choices:
            question.choice_set.create(choice_text=choice_text, votes=votes)
        made += 1
    print("seed: %d categories, %d tags, %d questions (%d new)" % (len(categories), len(tags), Question.objects.count(), made))


# ---------------------------------------------------------------------------------------------
# accounts
# ---------------------------------------------------------------------------------------------

# The groups the default accounts are in, and the permissions each gets on every model of the
# project's own apps (not those of django.contrib): an editor adds, changes, deletes and views;
# a viewer only views.
GROUPS = {"editor": ("Editors", ("add", "change", "delete", "view")), "viewer": ("Viewers", ("view",))}


def payload():
    raw = os.environ.get("DJANGO_SITE_ACCOUNTS", "")
    return json.loads(base64.b64decode(raw).decode()) if raw else {}


def own_permissions(actions):
    from django.apps import apps
    from django.contrib.auth.models import Permission
    from django.contrib.contenttypes.models import ContentType

    labels = [config.label for config in apps.get_app_configs() if not config.name.startswith("django.")]
    types = ContentType.objects.filter(app_label__in=labels)
    codenames = Permission.objects.filter(content_type__in=types)
    return [p for p in codenames if p.codename.split("_", 1)[0] in actions]


def group_for(role):
    from django.contrib.auth.models import Group

    name, actions = GROUPS[role]
    group, _ = Group.objects.get_or_create(name=name)
    group.permissions.set(own_permissions(actions))
    return group


def accounts(verb):
    setup_django()
    from django.contrib.auth import get_user_model

    User = get_user_model()
    data = payload()
    if verb == "installed":
        sys.exit(0 if User.objects.filter(is_superuser=True).exists() else 1)
    if verb == "owner":
        owner = data.get("owner") or {}
        user, created = User.objects.get_or_create(username=owner["name"])
        user.email = owner.get("email", "")
        user.is_staff = user.is_superuser = user.is_active = True
        user.set_password(owner["password"])
        user.save()
        print("owner: %s, a superuser (%s)" % (user.username, "created" if created else "updated"))
        return
    if verb == "add":
        for account in data.get("accounts", []):
            user, created = User.objects.get_or_create(username=account["name"])
            user.email = account.get("email", "")
            user.is_active = True
            user.is_staff = True
            role = account.get("role", "")
            user.is_superuser = role == "superuser"
            user.set_password(account["password"])
            user.save()
            user.groups.set([group_for(role)] if role in GROUPS else [])
            print("account: %s, %s (%s)" % (user.username, role or "staff", "created" if created else "updated"))
        return
    if verb == "cancel":
        owner = (data.get("owner") or {}).get("name")
        for account in data.get("accounts", []):
            if account["name"] == owner:
                continue
            deleted, _ = User.objects.filter(username=account["name"]).delete()
            print("account: %s %s" % (account["name"], "deleted" if deleted else "was not there"))
        return
    if verb == "list":
        for user in User.objects.order_by("id"):
            kind = "superuser" if user.is_superuser else ("staff" if user.is_staff else "no admin access")
            groups = ", ".join(group.name for group in user.groups.order_by("name")) or "no group"
            print("  %s <%s> %s, %s%s" % (user.username, user.email or "no address", kind, groups, "" if user.is_active else " (inactive)"))
        return
    sys.exit("accounts: owner, add, cancel, list or installed")


def main(argv):
    verb = argv[1] if len(argv) > 1 else ""
    if verb == "settings":
        write_settings()
    elif verb == "polls":
        write_polls()
    elif verb == "seed":
        seed()
    elif verb == "accounts":
        accounts(argv[2] if len(argv) > 2 else "")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
