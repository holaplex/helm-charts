import { Namespace, Context } from "@ory/keto-namespace-types"
class User implements Namespace {}

class Webhook implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Organization[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)),
  }
}

class Credential implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Organization[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)),
  }
}

class Customer implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Project[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.delete(ctx)),
  }
}

class Mint implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Drop[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.delete(ctx)),
  }
}

class Drop implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Project[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.delete(ctx)),
  }
}

class Project implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Organization[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.view(ctx)) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.edit(ctx)) ||
      this.permits.delete(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) ||
      this.related.parents.traverse((parent) => parent.permits.delete(ctx)),
  }
}

class Organization implements Namespace {
  related: {
    owners: User[]
    editors: User[]
    viewers: User[]
    parents: Organization[]
  }

  permits = {
    view: (ctx: Context): boolean =>
      this.related.viewers.includes(ctx.subject) ||
      this.permits.edit(ctx),
    edit: (ctx: Context): boolean =>
      this.related.editors.includes(ctx.subject) ||
      this.permits.delete(ctx),
    invite: (ctx: Context): boolean =>
      this.permits.view(ctx),
    delete: (ctx: Context): boolean =>
      this.related.owners.includes(ctx.subject) || 
      this.related.parents.traverse((parent) => parent.permits.delete(ctx)),
  }
}

