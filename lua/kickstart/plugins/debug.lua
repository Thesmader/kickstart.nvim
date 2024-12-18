-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_setup = false,
      automatic_installation = false,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {
        function(config)
          require('mason-nvim-dap').default_setup(config)
        end,
        python = function(config)
          config.adapters = {
            type = 'executable',
            command = 'python',
            args = { '-m', 'debugpy.adapter' },
            enrich_config = function(final_config, on_config)
              local enriched = vim.deepcopy(final_config)
              local placeholders = {
                ['${file}'] = function(_)
                  return vim.fn.expand '%:p'
                end,
                ['${fileBasename}'] = function(_)
                  return vim.fn.expand '%:t'
                end,
                ['${fileBasenameNoExtension}'] = function(_)
                  return vim.fn.fnamemodify(vim.fn.expand '%:t', ':r')
                end,
                ['${fileDirname}'] = function(_)
                  return vim.fn.expand '%:p:h'
                end,
                ['${fileExtname}'] = function(_)
                  return vim.fn.expand '%:e'
                end,
                ['${relativeFile}'] = function(_)
                  return vim.fn.expand '%:.'
                end,
                ['${relativeFileDirname}'] = function(_)
                  return vim.fn.fnamemodify(vim.fn.expand '%:.:h', ':r')
                end,
                ['${workspaceFolder}'] = function(_)
                  return vim.fn.getcwd()
                end,
                ['${workspaceFolderBasename}'] = function(_)
                  return vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
                end,
                ['${env:([%w_]+)}'] = function(match)
                  return os.getenv(match) or ''
                end,
              }

              if enriched.envFile then
                local file_path = enriched.envFile
                for key, fn in pairs(placeholders) do
                  file_path = file_path:gsub(key, fn)
                end

                for line in io.lines(file_path) do
                  local vals = {}
                  for val in string.gmatch(line, '[^=]+') do
                    table.insert(vals, val)
                  end
                  if not enriched.env then
                    enriched.env = {}
                  end
                  enriched.env[vals[1]] = vals[2]
                end
              end

              on_config(enriched)
            end,
          }

          require('mason-nvim-dap').default_setup(config)
        end,
      },

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
      },
    }

    -- Basic debugging keymaps, feel free to change to your liking!
    vim.keymap.set('n', '<leader>dc', dap.continue, { desc = 'Debug: Start/Continue' })
    vim.keymap.set('n', '<leader>dC', dap.close, { desc = 'Debug: Stop' })
    vim.keymap.set('n', '<leader>dr', dap.restart, { desc = 'Debug: Restart' })
    vim.keymap.set('n', '<leader>di', dap.step_into, { desc = 'Debug: Step Into' })
    vim.keymap.set('n', '<leader>do', dap.step_over, { desc = 'Debug: Step Over' })
    vim.keymap.set('n', '<leader>dO', dap.step_out, { desc = 'Debug: Step Out' })
    vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
    vim.keymap.set('n', '<leader>B', function()
      dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
    end, { desc = 'Debug: Set Breakpoint' })
    vim.keymap.set('n', '<leader>du', dapui.toggle, { desc = 'Toggle DAP UI' })

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    ---@diagnostic disable-next-line: missing-fields
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      ---@diagnostic disable-next-line: missing-fields
      layouts = {
        {
          elements = {
            {
              id = 'scopes',
              size = 0.25,
            },
            {
              id = 'breakpoints',
              size = 0.25,
            },
            {
              id = 'stacks',
              size = 0.25,
            },
            {
              id = 'watches',
              size = 0.25,
            },
          },
          position = 'right',
          size = 40,
        },
        {
          elements = { {
            id = 'repl',
            size = 0.5,
          }, {
            id = 'console',
            size = 0.5,
          } },
          position = 'bottom',
          size = 10,
        },
      },
      ---@diagnostic disable-next-line: missing-fields
      controls = {
        -- icons = {
        --   pause = '⏸',
        --   play = '▶',
        --   step_into = '⏎',
        --   step_over = '⏭',
        --   step_out = '⏮',
        --   step_back = 'b',
        --   run_last = '▶▶',
        --   terminate = '⏹',
        --   disconnect = '⏏',
        -- },
      },
    }

    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    vim.keymap.set('n', '<F7>', dapui.toggle, { desc = 'Debug: See last session result.' })

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    require('dap-go').setup()
  end,
}
