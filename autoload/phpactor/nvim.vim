let s:lock = v:null

func! phpactor#nvim#asyncCall(action, arguments)
    " TODO: Include either the original "action" in the response or a request
    " ID (probably better to include both)
    if s:lock != v:null
        echo "An asynchronous RPC '" . s:lock . "' action is already running"
        return
    endif

    let s:lock = a:action
    let callbacks = {
    \   'on_stdout': function('phpactor#nvim#asyncHandle'),
    \   'on_stderr': function('phpactor#nvim#asyncHandle'),
    \   'on_exit': function('phpactor#nvim#asyncHandle')
    \ }
    let job = jobstart([ g:phpactorPhpBin, g:phpactorbinpath, 'rpc', '--working-dir=' . g:phpactorInitialCwd ], callbacks)

    let request = { "action": a:action, "parameters": a:arguments }

    call chansend(job, json_encode(request))
    call chanclose(job, 'stdin')

    return job
endfunc

let s:stdout = []
let s:stderr = []

func! phpactor#nvim#asyncHandle(jobId, data, event)
    if a:event == 'stdout'
        call extend(s:stdout, a:data)
        return
    elseif a:event == 'stderr'
        call extend(s:stderr, a:data)
        return
    endif

    if a:data != 0
        echo "Phpactor returned an error: " . join(s:stderr)
        return
    endif

    let s:lock = v:null
    call phpactor#rpc#handleRawResponse(join(s:stdout))

    let s:stdout = []
    let s:stderr = []
endfunc