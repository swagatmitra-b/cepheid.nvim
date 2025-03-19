# cepheid.nvim

This is a todo plugin. You can switch to the `plain` branch for a single list experience. The default `main` branch version
allows you to create and manage multiple lists. 

## Installation

### lazy.nvim 

```lua
    {
        "swagatmitra-b/cepheid.nvim",
        branch = "main" -- default, you may switch to 'plain'  
        config = function ()
            require("todo").setup({ -- config goes here 
            })
        end
    }
```
## Usage

### `main` version

#### Adding todos

When adding a new todo, it is necessary to specify the list by adding the list-name at the end of the input preceded by two
dashes (`--listname`). If the list does not exist, it will be created. 

```markdown
go swimming on fridays --march
```
"go swimming on fridays" gets added to the `march` list.

#### Modifying todos

Todos (and their list names) can be modified like regular text in a neovim buffer. 

#### Creating/Deleting lists

Lists are created alongside their todos. They cannot be added from the list buffer.
This is to prevent empty lists (lists with no todos) from being created.

To delete a list, you must remove the list-name from the line and exit the buffer (leaving the line blank).
Deleting the line entirely will not work.

### `plain` version

Todos can be added, modified and deleted normally in the buffer.

## Configuration

```lua
{
    -- default
    sort_pending = false, -- sorts the todos according to their pending state 
    window = {
        width = 0.5,
        height = 0.35,
        border = "rounded"
    },
    keys = {
        add = "<A-i>",
        list = "<A-l>",
        toggle_pending = "<leader>d",
        close = "q",
        enter_list = "<leader>d"
    }
}
```
## Contribution

Feel free to raise an issue or initiate a pull request.
