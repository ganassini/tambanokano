local ffi = require("ffi")

local lib_path = "./target/release/libtambanokano.so"
local fractal_lib

local success, err = pcall(function()
    fractal_lib = ffi.load(lib_path)
end)

if not success then
    print("failed to load Rust library from: " .. lib_path)
    print("error: " .. tostring(err))
    print("make sure you've compiled the Rust library with: cargo build --release")
    -- https://love2d.org/wiki/love.event.quit
    love.event.quit()
    return
end

ffi.cdef[[
    void generate_fractal(unsigned char* buffer, int width, int height, 
                         double center_x, double center_y, double zoom, int iterations);
]]

function parseArguments(args)
    local params = {
        center_x = -0.5,
        center_y = 0.0,
        zoom = 1.0,
        iterations = 100,
        case_study = false
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "--help" or arg == "-h" then
            print("\nTambanokano Fractal Viewer")
            print("usage: love . [options]")
            print("options:")
            print("  --center-x <value>     initial center X coordinate (default: -0.5)")
            print("  --center-y <value>     initial center Y coordinate (default: 0.0)")
            print("  --zoom <value>         initial zoom level (default: 1.0)")
            print("  --iterations <value>   initial iteration count (default: 100)")
            print("  --case-study           run automated case study")
            print("  --help, -h             show this help message")
            print("")
            love.event.quit()
            return params
        elseif arg == "--center-x" then
            if i + 1 <= #args then
                local value = tonumber(args[i + 1])
                if value then
                    params.center_x = value
                    i = i + 1
                else
                    print("invalid value for --center-x, using default")
                end
            else
                print("--center-x requires a value, using default")
            end
        elseif arg == "--center-y" then
            if i + 1 <= #args then
                local value = tonumber(args[i + 1])
                if value then
                    params.center_y = value
                    i = i + 1
                else
                    print("invalid value for --center-y, using default")
                end
            else
                print("--center-y requires a value, using default")
            end
        elseif arg == "--zoom" then
            if i + 1 <= #args then
                local value = tonumber(args[i + 1])
                if value and value > 0 then
                    params.zoom = value
                    i = i + 1
                else
                    print("invalid value for --zoom (must be positive), using default")
                end
            else
                print("--zoom requires a value, using default")
            end
        elseif arg == "--iterations" then
            if i + 1 <= #args then
                local value = tonumber(args[i + 1])
                if value and value > 0 and value == math.floor(value) then
                    params.iterations = value
                    i = i + 1
                else
                    print("invalid value for --iterations (must be positive integer), using default")
                end
            else
                print("--iterations requires a value, using default")
            end
        elseif arg == "--case-study" then
            params.case_study = true
        end
        
        i = i + 1
    end
    
    return params
end

local initial_params = parseArguments(arg)

local GameState = {
    -- fractal parameters
    center_x = initial_params.center_x,
    center_y = initial_params.center_y,
    zoom = initial_params.zoom,
    iterations = initial_params.iterations,
    
    -- rendering
    fractal_texture = nil,
    
    -- UI
    time = 0,
    auto_animate = false,
    show_help = true,
    needs_regenerate = true,
}

-- this is global so we can zoom with the mousewheel
local dt
-- detect case Study (now using parsed parameter)
local caseStudy = initial_params.case_study
local caseTimer = 0
local screenshotTaken = false

function love.load()
    -- https://love2d.org/wiki/love.window.setTitle
    love.window.setTitle("Tambanokano")
    -- https://love2d.org/wiki/love.graphics.setBackgroundColor
    love.graphics.setBackgroundColor(0.05, 0.05, 0.15)
    
    print("starting with parameters:")
    print("  center: (" .. string.format("%.4f", GameState.center_x) .. ", " .. string.format("%.4f", GameState.center_y) .. ")")
    print("  zoom: " .. string.format("%.2f", GameState.zoom))
    print("  iterations: " .. GameState.iterations)
    if caseStudy then
        print("  Running case study mode")
    end
    
    generateFractal()
    
    print("\nControls:")
    print("  arrow keys   - move")
    print("  q/e          - zoom in/out") 
    print("  +/-          - more/less iterations")
    print("  space        - toggle auto-animation")
    print("  r            - reset to initial view")
    print("  s            - save screenshot")
    print("  h            - toggle help")
    print("  ESC          - exit")
end

function generateFractal()
    local width, height = 800, 800
    
    local buffer = ffi.new("unsigned char[?]", width * height * 4)
    
    fractal_lib.generate_fractal(
        buffer, width, height,
        GameState.center_x, GameState.center_y, GameState.zoom, GameState.iterations
    )
    
    local img_string = ffi.string(buffer, width * height * 4)
    -- https://love2d.org/wiki/love.image.newImageData
    local image_data = love.image.newImageData(width, height, "rgba8", img_string)
    -- https://love2d.org/wiki/love.graphics.newImage
    GameState.fractal_texture = love.graphics.newImage(image_data)
    
    GameState.needs_regenerate = false
    
    print("generated fractal: center(" .. 
          string.format("%.4f", GameState.center_x) .. ", " .. 
          string.format("%.4f", GameState.center_y) .. ") zoom=" .. 
          string.format("%.2f", GameState.zoom) .. " iterations=" .. GameState.iterations)
end

function love.update(td)
    dt = td
    GameState.time = GameState.time + dt
    
    local move_speed = 1.5 / GameState.zoom * dt
    local zoom_speed = 2.0 * dt

    if caseStudy then
      caseTimer = caseTimer + dt
      if caseTimer <= 0.30 then
        GameState.center_x = GameState.center_x - move_speed
        GameState.needs_regenerate = true
      elseif caseTimer <= 0.73 then
        GameState.center_y = GameState.center_y + move_speed
        GameState.needs_regenerate = true
      elseif caseTimer <= 3 then
        GameState.zoom = GameState.zoom * (1.0 + zoom_speed)
        GameState.needs_regenerate = true
      elseif caseTimer <= 3.1 then
        GameState.center_y = GameState.center_y + move_speed
        GameState.needs_regenerate = true
      elseif caseTimer <= 7.5 then
        GameState.zoom = GameState.zoom * (1.0 + zoom_speed)
        GameState.needs_regenerate = true 
      elseif caseTimer > 7.5 and not screenshotTaken then
        local filename = os.date("fractal-case-%Y%m%d-%H%M%S.png")
        love.graphics.captureScreenshot(function(filename)
        print("case study screenshot saved! closing application in 5 seconds")
        end)
        screenshotTaken = true
      elseif caseTimer >=13 then
        love.event.quit()
      end
      if GameState.needs_regenerate then
        generateFractal()
      end
      return
    end
    
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("left") then 
        GameState.center_x = GameState.center_x - move_speed
        GameState.needs_regenerate = true
    end
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("right") then 
        GameState.center_x = GameState.center_x + move_speed
        GameState.needs_regenerate = true
    end
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("up") then 
        GameState.center_y = GameState.center_y - move_speed
        GameState.needs_regenerate = true
    end
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("down") then 
        GameState.center_y = GameState.center_y + move_speed
        GameState.needs_regenerate = true
    end
    
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("q") then 
        GameState.zoom = GameState.zoom * (1.0 + zoom_speed)
        GameState.needs_regenerate = true
    end
    -- https://love2d.org/wiki/love.keyboard.isDown
    if love.keyboard.isDown("e") then 
        new_zoom = GameState.zoom / (1.0 + zoom_speed)
        if new_zoom > 1 then
          GameState.zoom = new_zoom
          GameState.needs_regenerate = true
        end
    end

    if GameState.auto_animate then
        GameState.zoom = GameState.zoom * (1.0 + zoom_speed * 0.5)
        GameState.needs_regenerate = true
    end

    if GameState.needs_regenerate then
        generateFractal()
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- https://love2d.org/wiki/love.event.quit
        love.event.quit()
    elseif key == "space" then
        GameState.auto_animate = not GameState.auto_animate
    elseif key == "r" then
        GameState.center_x = initial_params.center_x
        GameState.center_y = initial_params.center_y
        GameState.zoom = initial_params.zoom
        GameState.iterations = initial_params.iterations
        GameState.needs_regenerate = true
    elseif key == "h" then
        GameState.show_help = not GameState.show_help
    elseif key == "s" then
        -- https://love2d.org/wiki/love.graphics.captureScreenshot
        local screenshot = love.graphics.captureScreenshot(os.date("./fractal-%Y%m%d-%H%M%S.png"))
        print("screenshot saved!")
    elseif key == "=" or key == "+" then
        GameState.iterations = GameState.iterations + 50
        GameState.needs_regenerate = true
    elseif key == "-" then
        GameState.iterations = math.max(10, GameState.iterations - 50)
        GameState.needs_regenerate = true
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        GameState.dragging = true
        GameState.last_mouse_x = x
        GameState.last_mouse_y = y
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        GameState.dragging = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if GameState.dragging then
        local move_speed = 0.005 / GameState.zoom
        GameState.center_x = GameState.center_x - dx * move_speed
        GameState.center_y = GameState.center_y - dy * move_speed
        GameState.needs_regenerate = true
    end
end

function love.wheelmoved(x, y)
    GameState.time = GameState.time + dt

    local move_speed = 1.5 / GameState.zoom * dt
    local zoom_speed = 2.0 * dt

    if y > 0 then
        GameState.zoom = GameState.zoom * (1.0 + zoom_speed)
        GameState.needs_regenerate = true
    elseif y < 0 then
        new_zoom = GameState.zoom / (1.0 + zoom_speed)
        if new_zoom > 1 then
          GameState.zoom = new_zoom
          GameState.needs_regenerate = true
        end
    end
end

function love.draw()
    if GameState.fractal_texture then
        -- https://love2d.org/wiki/love.graphics.draw
        love.graphics.draw(GameState.fractal_texture, 0, 0)
    end

    if GameState.show_help then
        -- https://love2d.org/wiki/love.graphics.setColor
        love.graphics.setColor(0, 0, 0, 0.6)
        -- https://love2d.org/wiki/love.graphics.rectangle
        love.graphics.rectangle("fill", 10, 10, 320, 160)
        -- https://love2d.org/wiki/love.graphics.setColor
        love.graphics.setColor(1, 1, 1, 1)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("arrow keys  - move", 20, 40)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("q / e       - zoom in / out", 20, 55)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("+ / -       - iterations +/-", 20, 70)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("space       - auto zoom animation", 20, 85)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("r           - reset view", 20, 100)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("s           - save screenshot", 20, 115)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("h           - toggle help", 20, 130)
        -- https://love2d.org/wiki/love.graphics.print
        love.graphics.print("ESC         - exit", 20, 145)
    end
end
