declare namespace wasm_bindgen {
    /* tslint:disable */
    /* eslint-disable */

    export class WorkerPool {
        free(): void;
        [Symbol.dispose](): void;
        static new(initial?: number | null, script_src?: string | null, worker_js_preamble?: string | null, wasm_bindgen_name?: string | null): WorkerPool;
        /**
         * Creates a new `WorkerPool` which immediately creates `initial` workers.
         *
         * The pool created here can be used over a long period of time, and it
         * will be initially primed with `initial` workers. Currently workers are
         * never released or gc'd until the whole pool is destroyed.
         *
         * # Errors
         *
         * Returns any error that may happen while a JS web worker is created and a
         * message is sent to it.
         */
        constructor(initial: number, script_src: string, worker_js_preamble: string, wasm_bindgen_name: string);
    }

    export function frb_dart_fn_deliver_output(call_id: number, ptr_: any, rust_vec_len_: number, data_len_: number): void;

    /**
     * # Safety
     *
     * This should never be called manually.
     */
    export function frb_dart_opaque_dart2rust_encode(handle: any, dart_handler_port: any): number;

    export function frb_dart_opaque_drop_thread_box_persistent_handle(ptr: number): void;

    export function frb_dart_opaque_rust2dart_decode(ptr: number): any;

    export function frb_get_rust_content_hash(): number;

    export function frb_pde_ffi_dispatcher_primary(func_id: number, port_: any, ptr_: any, rust_vec_len_: number, data_len_: number): void;

    export function frb_pde_ffi_dispatcher_sync(func_id: number, ptr_: any, rust_vec_len_: number, data_len_: number): any;

    /**
     * ## Safety
     * This function reclaims a raw pointer created by [`TransferClosure`], and therefore
     * should **only** be used in conjunction with it.
     * Furthermore, the WASM module in the worker must have been initialized with the shared
     * memory from the host JS scope.
     */
    export function receive_transfer_closure(payload: number, transfer: any[]): void;

    export function wasm_start_callback(): void;

}
declare type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

declare interface InitOutput {
    readonly frb_dart_fn_deliver_output: (a: number, b: any, c: number, d: number) => void;
    readonly frb_get_rust_content_hash: () => number;
    readonly frb_pde_ffi_dispatcher_primary: (a: number, b: any, c: any, d: number, e: number) => void;
    readonly frb_pde_ffi_dispatcher_sync: (a: number, b: any, c: number, d: number) => any;
    readonly __wbg_workerpool_free: (a: number, b: number) => void;
    readonly workerpool_new: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => [number, number, number];
    readonly workerpool_new_raw: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => [number, number, number];
    readonly frb_dart_opaque_dart2rust_encode: (a: any, b: any) => number;
    readonly frb_dart_opaque_drop_thread_box_persistent_handle: (a: number) => void;
    readonly frb_dart_opaque_rust2dart_decode: (a: number) => any;
    readonly frb_rust_vec_u8_free: (a: number, b: number) => void;
    readonly frb_rust_vec_u8_new: (a: number) => number;
    readonly frb_rust_vec_u8_resize: (a: number, b: number, c: number) => number;
    readonly receive_transfer_closure: (a: number, b: number, c: number) => [number, number];
    readonly wasm_start_callback: () => void;
    readonly wasm_bindgen_45412df3e7992a42___convert__closures_____invoke___web_sys_cbdbd214522c8e58___features__gen_Event__Event______true_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_45412df3e7992a42___convert__closures_____invoke___web_sys_cbdbd214522c8e58___features__gen_MessageEvent__MessageEvent______true_: (a: number, b: number, c: any) => void;
    readonly memory: WebAssembly.Memory;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_destroy_closure: (a: number, b: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_thread_destroy: (a?: number, b?: number, c?: number) => void;
    readonly __wbindgen_start: (a: number) => void;
}

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput>, memory?: WebAssembly.Memory, thread_stack_size?: number }} module_or_path - Passing `InitInput` directly is deprecated.
 * @param {WebAssembly.Memory} memory - Deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
declare function wasm_bindgen (module_or_path?: { module_or_path: InitInput | Promise<InitInput>, memory?: WebAssembly.Memory, thread_stack_size?: number } | InitInput | Promise<InitInput>, memory?: WebAssembly.Memory): Promise<InitOutput>;
