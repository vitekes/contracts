const webpack = require('webpack');
const getCacheIdentifier = require('react-dev-utils/getCacheIdentifier');

const shouldUseSourceMap = process.env.GENERATE_SOURCEMAP !== 'false';

module.exports = {
    webpack: {
        configure: (webpackConfig, { env, paths }) => {
            const isEnvDevelopment = env === 'development';
            const isEnvProduction = env === 'production';
            const loaders = webpackConfig.module.rules.find(rule => Array.isArray(rule.oneOf)).oneOf;

            // Add babel-loader configuration
            loaders.splice(loaders.length - 1, 0, {
                test: /\.(js|mjs|cjs)$/,
                exclude: /@babel(?:\/|\\{1,2})runtime/,
                loader: require.resolve('babel-loader'),
                options: {
                    babelrc: false,
                    configFile: false,
                    compact: false,
                    presets: [
                        [
                            require.resolve('babel-preset-react-app/dependencies'),
                            { helpers: true },
                        ],
                    ],
                    cacheDirectory: true,
                    cacheCompression: false,
                    cacheIdentifier: getCacheIdentifier(
                        isEnvProduction ?
                        'production' :
                        isEnvDevelopment && 'development', [
                            'babel-plugin-named-asset-import',
                            'babel-preset-react-app',
                            'react-dev-utils',
                            'react-scripts',
                        ]
                    ),
                    sourceMaps: shouldUseSourceMap,
                    inputSourceMap: shouldUseSourceMap,
                },
            });

            // Fallback configuration for Buffer, process, etc.
            webpackConfig.resolve.fallback = {
                buffer: require.resolve('buffer/'),
                process: require.resolve('process/browser.js'), // Add full extension here
                stream: require.resolve('stream-browserify'),
                crypto: require.resolve('crypto-browserify'),
            };

            // Add ProvidePlugin for Buffer and process
            webpackConfig.plugins.push(
                new webpack.ProvidePlugin({
                    Buffer: ['buffer', 'Buffer'],
                    process: 'process/browser.js', // Add full extension here
                })
            );

            return webpackConfig;
        },
    },
};