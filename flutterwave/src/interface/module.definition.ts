import { ConfigurableModuleBuilder } from "@nestjs/common";
import {ModuleOptions } from ".";

export const { ConfigurableModuleClass, MODULE_OPTIONS_TOKEN } =
  new ConfigurableModuleBuilder<ModuleOptions>()
    .setExtras(
      {
        isGlobal: false,
      },
      (definition, extras) => ({
        ...definition,
        global: extras.isGlobal,
      })
    )
    .build();
